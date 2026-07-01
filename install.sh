#!/bin/bash
# DentalCare Pro — Install / Update Script (produzione)
# Macchina deploy: 192.168.0.72  —  cartella: ~/docker/dentalcarepro/
# DB: dentalcare_prod su 192.168.0.173
#
# Uso:
#   ./install.sh           primo avvio o aggiornamento completo
#   ./install.sh --update  solo git pull + rebuild (salta check config)
#
# Espone il frontend su http://<host>:8181 (nginx :4200 nel container).
# Il backend NON è esposto: l'nginx del frontend proxa /api al backend interno.

set -euo pipefail

REPO_URL="https://github.com/fpapale/dentalcare.git"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_CONTAINER="dentalcarepro-backend"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 1. Requisiti ─────────────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || err "Docker non trovato. Installare Docker Engine."
command -v git    >/dev/null 2>&1 || err "git non trovato."
docker compose version >/dev/null 2>&1 || err "Docker Compose plugin non trovato."
log "Requisiti verificati."

cd "$DEPLOY_DIR"

# ── 2. Git: clone o pull ─────────────────────────────────────────────────────
if [ ! -d ".git" ]; then
  warn "Repository non trovato — clone da $REPO_URL"
  git clone "$REPO_URL" /tmp/dentalcare_clone
  cp -r /tmp/dentalcare_clone/. .
  rm -rf /tmp/dentalcare_clone
  log "Clone completato."
else
  log "Aggiornamento repository..."
  git pull origin master
  log "Repository aggiornato: $(git log -1 --format='%h %s')"
fi

# ── 3. Config esterna (credenziali, fuori dall'immagine) ─────────────────────
if [ "${1:-}" != "--update" ]; then
  CONFIG_FILE="$DEPLOY_DIR/config/application-prod.properties"

  if [ ! -f "$CONFIG_FILE" ]; then
    cp "$DEPLOY_DIR/config/application-prod.properties.example" "$CONFIG_FILE"
    log "Creato config/application-prod.properties da template (già puntato a dentalcare_prod)."
    warn "Verifica password DB e app.jwt.secret in: $CONFIG_FILE"
  else
    log "config/application-prod.properties già presente."
  fi

  if [ ! -f "$DEPLOY_DIR/.env" ]; then
    cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
    log "Creato .env da template (FRONTEND_PORT=8181)."
  else
    log ".env già presente."
  fi
fi

# ── 4. Database (opzionale: crea/ricrea dentalcare_prod) ─────────────────────
if [ "${1:-}" != "--update" ]; then
  DB_HOST="192.168.0.173"
  DB_PORT="5432"
  DB_SUPERUSER="postgres"
  PROD_DB="dentalcare_prod"

  read -r -p "Creare/RICREARE il database ${PROD_DB} su ${DB_HOST}? [y/N] " ANSWER
  if [[ "${ANSWER:-N}" =~ ^[YySs]$ ]]; then
    command -v psql >/dev/null 2>&1 || err "psql non trovato: serve il client PostgreSQL per (ri)creare il DB."
    warn "Verrà ELIMINATO e ricreato il database ${PROD_DB} (tutti i dati attuali andranno persi)."
    read -r -p "Per confermare la cancellazione scrivi 'SI': " CONFIRM
    [ "$CONFIRM" = "SI" ] || err "Operazione DB annullata."

    if [ -z "${PGPASSWORD:-}" ]; then
      read -r -s -p "Password utente ${DB_SUPERUSER}: " PGPASSWORD; echo
      export PGPASSWORD
    fi

    log "Arresto container per liberare le connessioni al DB..."
    docker compose down 2>/dev/null || true

    log "Drop + ricreazione ${PROD_DB} da database/install.sql..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_SUPERUSER" -d postgres \
         -c "DROP DATABASE IF EXISTS \"${PROD_DB}\" WITH (FORCE);" \
      || err "Drop database fallito."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_SUPERUSER" -d postgres \
         -v ON_ERROR_STOP=1 -v dbname="${PROD_DB}" -f "$DEPLOY_DIR/database/install.sql" \
      || err "Creazione database fallita."
    log "Database ${PROD_DB} ricreato da install.sql."
  else
    log "DB ${PROD_DB} assunto già esistente — deploy della sola parte applicativa."
  fi
fi

# ── 5. Modelli AI ONNX (copia automatica se assenti) ─────────────────────────
# I modelli sono gitignored (non arrivano col clone). Se mancano, li copia dalla
# sorgente MODELS_SRC (default: 192.168.0.72). Su quella macchina sono già presenti
# quindi lo step viene saltato. Override: MODELS_SRC=... ./install.sh
if [ "${1:-}" != "--update" ]; then
  MODELS_DIR="$DEPLOY_DIR/dentalcare-ai-service/models"
  MODELS_SRC="${MODELS_SRC:-fpapale@192.168.0.72:~/docker/dentalcarepro/dentalcare-ai-service/models}"
  mkdir -p "$MODELS_DIR"
  for MODEL in dentex_fdi_v1.onnx dentex_disease_v1.onnx; do
    if [ -f "$MODELS_DIR/$MODEL" ]; then
      log "Modello $MODEL già presente."
    else
      warn "Modello $MODEL assente — copia da $MODELS_SRC ..."
      if command -v rsync >/dev/null 2>&1; then
        rsync -az "$MODELS_SRC/$MODEL" "$MODELS_DIR/$MODEL" \
          || warn "Copia $MODEL fallita — copiarlo a mano in $MODELS_DIR (l'AI resterà 'loaded:false')."
      else
        scp "$MODELS_SRC/$MODEL" "$MODELS_DIR/$MODEL" \
          || warn "Copia $MODEL fallita — copiarlo a mano in $MODELS_DIR (l'AI resterà 'loaded:false')."
      fi
    fi
  done
fi

# ── 6. Build e avvio ─────────────────────────────────────────────────────────
log "Build immagini e avvio container..."
docker compose up -d --build

# ── 6. Health check backend ──────────────────────────────────────────────────
log "Attendo healthcheck backend (max 120s)..."
ELAPSED=0
until docker inspect --format='{{.State.Health.Status}}' "$BACKEND_CONTAINER" 2>/dev/null | grep -q "healthy"; do
  if [ $ELAPSED -ge 120 ]; then
    err "Backend non healthy dopo 120s. Log: docker logs $BACKEND_CONTAINER"
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done
log "Backend healthy."

FRONTEND_PORT=$(grep -E '^FRONTEND_PORT=' "$DEPLOY_DIR/.env" 2>/dev/null | cut -d= -f2 || echo 8181)
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
log "Deploy completato."
echo -e "  Frontend : ${GREEN}http://${HOST_IP}:${FRONTEND_PORT:-8181}/${NC}"
echo -e "  DB       : dentalcare_prod @ 192.168.0.173"
echo -e "  Login    : admin@demo.dentalcare.it / DemoAdmin1!"
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
echo ""
