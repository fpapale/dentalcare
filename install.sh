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

# ── 4. Build e avvio ─────────────────────────────────────────────────────────
log "Build immagini e avvio container..."
docker compose up -d --build

# ── 5. Health check backend ──────────────────────────────────────────────────
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
