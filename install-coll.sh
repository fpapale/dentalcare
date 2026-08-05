#!/bin/bash
# DentalCare Pro — Install / Update COLLAUDO (#41)
# Macchina deploy: 192.168.0.72  —  cartella: ~/docker/dentalcarepro-coll/
# DB: dentalcare_coll su 192.168.0.173  —  stack parallelo a prod (nomi/porta/profilo distinti)
#
# Uso:
#   ./install-coll.sh           primo avvio o aggiornamento completo
#   ./install-coll.sh --update  solo git pull + rebuild (salta check config)
#
# Espone il frontend su http://<host>:8082 (nginx :4200 nel container).

set -euo pipefail

REPO_URL="https://github.com/fpapale/dentalcare.git"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_CONTAINER="dentalcarepro-coll-backend"
COMPOSE="docker compose -f docker-compose.coll.yml"

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
  git clone "$REPO_URL" /tmp/dentalcare_coll_clone
  cp -r /tmp/dentalcare_coll_clone/. .
  rm -rf /tmp/dentalcare_coll_clone
  log "Clone completato."
else
  log "Aggiornamento repository..."
  git pull origin master
  log "Repository aggiornato: $(git log -1 --format='%h %s')"
fi

# ── 3. Config esterna (credenziali COLLAUDO, DIVERSE da prod) ─────────────────
if [ "${1:-}" != "--update" ]; then
  CONFIG_FILE="$DEPLOY_DIR/config/application-coll.properties"

  if [ ! -f "$CONFIG_FILE" ]; then
    cp "$DEPLOY_DIR/config/application-coll.properties.example" "$CONFIG_FILE"
    log "Creato config/application-coll.properties da template (puntato a dentalcare_coll)."
    warn "Configura in $CONFIG_FILE prima di procedere (valori DIVERSI da prod):"
    warn "  - spring.datasource.password (password DB coll)"
    warn "  - app.jwt.secret (openssl rand -base64 48)"
    warn "  - app.encryption.master-key (openssl rand -hex 32, 64 hex) — OBBLIGATORIO:"
    warn "    senza una chiave valida il backend NON si avvia (fail-fast)."
    warn "    NON riusare la chiave di prod: separa i dati cifrati dei due ambienti."
  else
    log "config/application-coll.properties già presente."
  fi

  if [ ! -f "$DEPLOY_DIR/.env" ]; then
    echo "FRONTEND_PORT=8082" > "$DEPLOY_DIR/.env"
    log "Creato .env (FRONTEND_PORT=8082)."
  else
    log ".env già presente."
  fi
fi

# ── 4. Database (opzionale: crea/ricrea dentalcare_coll) ─────────────────────
if [ "${1:-}" != "--update" ]; then
  DB_HOST="192.168.0.173"
  DB_PORT="5432"
  DB_SUPERUSER="postgres"
  COLL_DB="dentalcare_coll"

  read -r -p "Creare/RICREARE il database ${COLL_DB} su ${DB_HOST}? [y/N] " ANSWER
  if [[ "${ANSWER:-N}" =~ ^[YySs]$ ]]; then
    command -v psql >/dev/null 2>&1 || err "psql non trovato: serve il client PostgreSQL per (ri)creare il DB."
    warn "Verrà ELIMINATO e ricreato il database ${COLL_DB} (tutti i dati attuali andranno persi)."
    read -r -p "Per confermare la cancellazione scrivi 'SI': " CONFIRM
    [ "$CONFIRM" = "SI" ] || err "Operazione DB annullata."

    if [ -z "${PGPASSWORD:-}" ]; then
      read -r -s -p "Password utente ${DB_SUPERUSER}: " PGPASSWORD; echo
      export PGPASSWORD
    fi

    log "Arresto container per liberare le connessioni al DB..."
    $COMPOSE down 2>/dev/null || true

    log "Drop + ricreazione ${COLL_DB} da database/install.sql..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_SUPERUSER" -d postgres \
         -c "DROP DATABASE IF EXISTS \"${COLL_DB}\" WITH (FORCE);" \
      || err "Drop database fallito."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_SUPERUSER" -d postgres \
         -v ON_ERROR_STOP=1 -v dbname="${COLL_DB}" -f "$DEPLOY_DIR/database/install.sql" \
      || err "Creazione database fallita."
    log "Database ${COLL_DB} ricreato da install.sql."
  else
    log "DB ${COLL_DB} assunto già esistente — deploy della sola parte applicativa."
  fi
fi

# ── 5. Modelli AI ONNX (copia automatica se assenti) ─────────────────────────
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
log "Build immagini e avvio container (stack coll)..."
$COMPOSE up -d --build

# ── 7. Health check backend ──────────────────────────────────────────────────
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

FRONTEND_PORT=$(grep -E '^FRONTEND_PORT=' "$DEPLOY_DIR/.env" 2>/dev/null | cut -d= -f2 || echo 8082)
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
log "Deploy COLLAUDO completato."
echo -e "  Frontend : ${GREEN}http://${HOST_IP}:${FRONTEND_PORT:-8082}/${NC}"
echo -e "  DB       : dentalcare_coll @ 192.168.0.173"
echo -e "  Demo     : disabilitata (nessuna credenziale demo esposta)"
$COMPOSE ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
echo ""
