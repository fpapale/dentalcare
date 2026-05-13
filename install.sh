#!/bin/bash
# DentalCare Pro — Install / Update Script
# Eseguire da: ~/docker/dentalcarepro/
# Usage:
#   ./install.sh          — primo avvio o aggiornamento completo
#   ./install.sh --update — solo git pull + rebuild (skip config check)

set -euo pipefail

REPO_URL="https://github.com/fpapale/dentalcare.git"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILES="-f docker-compose.yml -f docker-compose.prod.yml"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 1. Requisiti ─────────────────────────────────────────────────────────────
command -v docker  >/dev/null 2>&1 || err "Docker non trovato. Installare Docker Engine."
command -v git     >/dev/null 2>&1 || err "git non trovato."
docker compose version >/dev/null 2>&1 || err "Docker Compose plugin non trovato."
log "Requisiti verificati."

cd "$DEPLOY_DIR"

# ── 2. Git: clone o pull ──────────────────────────────────────────────────────
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

# ── 3. File di configurazione ─────────────────────────────────────────────────
if [ "${1:-}" != "--update" ]; then

  CONFIG_BACKEND="$DEPLOY_DIR/config/backend/application.properties"
  CONFIG_FRONTEND="$DEPLOY_DIR/config/frontend/default.conf"

  mkdir -p "$DEPLOY_DIR/config/backend" "$DEPLOY_DIR/config/frontend"

  if [ ! -f "$CONFIG_BACKEND" ]; then
    cp "$DEPLOY_DIR/config/backend/application.properties.example" "$CONFIG_BACKEND"
    warn "Creato config/backend/application.properties da template."
    warn ">>> MODIFICA il file con host DB, username e password reali prima di continuare <<<"
    warn "File: $CONFIG_BACKEND"
    read -r -p "Premi INVIO quando il file è configurato (Ctrl+C per annullare)..."
  else
    log "config/backend/application.properties già presente."
  fi

  if [ ! -f "$CONFIG_FRONTEND" ]; then
    cp "$DEPLOY_DIR/config/frontend/default.conf.example" "$CONFIG_FRONTEND"
    log "Creato config/frontend/default.conf da template."
  else
    log "config/frontend/default.conf già presente."
  fi

  if [ ! -f "$DEPLOY_DIR/.env" ]; then
    cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
    log "Creato .env da template. FRONTEND_PORT default=8081."
  else
    log ".env già presente."
  fi

fi

# ── 4. Build e avvio container ────────────────────────────────────────────────
log "Build immagini e avvio container..."
docker compose $COMPOSE_FILES up -d --build

# ── 5. Health check ───────────────────────────────────────────────────────────
log "Attendo healthcheck backend (max 90s)..."
ELAPSED=0
until docker inspect --format='{{.State.Health.Status}}' dentalcarepro-backend-prod 2>/dev/null | grep -q "healthy"; do
  if [ $ELAPSED -ge 90 ]; then
    err "Backend non healthy dopo 90s. Controlla: docker logs dentalcarepro-backend-prod"
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

FRONTEND_PORT=$(grep FRONTEND_PORT "$DEPLOY_DIR/.env" 2>/dev/null | cut -d= -f2 || echo 8081)
log "Deploy completato."
echo ""
echo -e "  Frontend : ${GREEN}http://$(hostname -I | awk '{print $1}'):${FRONTEND_PORT:-8081}/${NC}"
echo -e "  Stato    : $(docker compose $COMPOSE_FILES ps --format 'table {{.Name}}\t{{.Status}}')"
echo ""
