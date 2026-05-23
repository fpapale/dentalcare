#!/usr/bin/env bash
# DentalCare Pro — Deploy script
# Uso: ./deploy.sh
# Prima esecuzione: crea config/backend/application.properties dal template.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "[1/4] Git pull..."
git pull origin master

echo "[2/4] Verifica config..."
if [ ! -f config/backend/application.properties ]; then
  echo ""
  echo "  ATTENZIONE: config/backend/application.properties non trovato."
  echo "  Copia il template e completa i valori:"
  echo "    cp config/backend/application.properties.example config/backend/application.properties"
  echo "    nano config/backend/application.properties"
  echo ""
  echo "  Poi riesegui ./deploy.sh"
  echo ""
  exit 1
fi

echo "[3/4] Build e avvio container..."
docker compose up -d --build

echo "[4/4] Stato container:"
docker compose ps

echo ""
echo "Deploy completato."
echo "Frontend: http://$(hostname -I | awk '{print $1}'):${FRONTEND_PORT:-80}"
