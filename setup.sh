#!/bin/bash
# DentalCare Pro — Bootstrap deploy (macchina 192.168.0.72)
# Prepara ~/docker/dentalcarepro, clona/aggiorna il repo e lancia install.sh.
#
# Uso:
#   ./setup.sh            primo avvio o aggiornamento completo
#   ./setup.sh --update   passa --update a install.sh (solo pull + rebuild)
#
# Può essere salvato/eseguito anche da una cartella qualsiasi: porta lui
# nella directory di deploy corretta.

set -euo pipefail

DEPLOY_DIR="${HOME}/docker/dentalcarepro"
REPO_URL="https://github.com/fpapale/dentalcare.git"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

command -v git >/dev/null 2>&1 || err "git non trovato."

# ── 1. Path di deploy ────────────────────────────────────────────────────────
if [ -d "$DEPLOY_DIR" ]; then
  log "Cartella di deploy già presente: $DEPLOY_DIR"
else
  mkdir -p "$DEPLOY_DIR"
  log "Creata cartella di deploy: $DEPLOY_DIR"
fi

cd "$DEPLOY_DIR"
log "Posizionato in: $(pwd)"

# ── 2. Repo: clone o pull ────────────────────────────────────────────────────
if [ -d ".git" ]; then
  log "Repository già presente — aggiornamento (git pull)..."
  git pull origin master
elif [ -z "$(ls -A "$DEPLOY_DIR" 2>/dev/null)" ]; then
  log "Cartella vuota — clone da $REPO_URL"
  git clone "$REPO_URL" .
else
  err "La cartella $DEPLOY_DIR non è vuota e non è un repo git. Svuotala o clona a mano."
fi
log "Repo a: $(git log -1 --format='%h %s')"

# ── 3. Lancia install.sh ─────────────────────────────────────────────────────
[ -f install.sh ] || err "install.sh non trovato nel repo."
chmod +x install.sh
log "Avvio install.sh ${*:-}"
./install.sh "$@"
