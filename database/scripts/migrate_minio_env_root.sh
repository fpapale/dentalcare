#!/usr/bin/env bash
#
# migrate_minio_env_root.sh — #40: migra i bucket MinIO alla radice per ambiente.
#
# Copia gli oggetti dai bucket <old-prefix><schema> ai bucket <new-prefix><schema>
# preservando le object key (patients/{patientId}/{docId}/{fileName} non cambia; cambia
# solo il bucket che li contiene). NON cancella mai i bucket vecchi: la rimozione è un
# passo manuale successivo (mc rb --force) dopo una finestra di osservazione.
#
# Default = DRY-RUN: elenca i bucket e confronta il conteggio oggetti sorgente/destinazione,
# senza scrivere nulla. Serve --apply per eseguire la copia reale.
#
# Prerequisito: MinIO client `mc` con due alias già configurati (mc alias set ...).
# Nessuna topologia interna è hardcoded qui: host/credenziali stanno negli alias mc locali.
#
# Uso:
#   ./migrate_minio_env_root.sh --source <mcAlias> [--target <mcAlias>] \
#       [--old-prefix dc-] [--new-prefix dc-prod-] [--apply]
#
# Esempi:
#   # verifica (nessuna scrittura): quali bucket verrebbero migrati e con quanti oggetti
#   ./migrate_minio_env_root.sh --source prod --old-prefix dc- --new-prefix dc-prod-
#   # esecuzione reale (dati clinici reali): la lancia il committente
#   ./migrate_minio_env_root.sh --source prod --new-prefix dc-prod- --apply

set -euo pipefail

SOURCE_ALIAS=""
TARGET_ALIAS=""
OLD_PREFIX="dc-"
NEW_PREFIX="dc-prod-"
APPLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)     SOURCE_ALIAS="${2:-}"; shift 2 ;;
    --target)     TARGET_ALIAS="${2:-}"; shift 2 ;;
    --old-prefix) OLD_PREFIX="${2:-}";  shift 2 ;;
    --new-prefix) NEW_PREFIX="${2:-}";  shift 2 ;;
    --apply)      APPLY=true;           shift ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argomento sconosciuto: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SOURCE_ALIAS" ]]; then
  echo "ERRORE: --source <mcAlias> è obbligatorio." >&2
  exit 2
fi
# Il target di default è lo stesso MinIO fisico della sorgente (stesso alias): la
# separazione è per bucket, non per server. --target serve solo se si migra a un altro MinIO.
TARGET_ALIAS="${TARGET_ALIAS:-$SOURCE_ALIAS}"

if ! command -v mc >/dev/null 2>&1; then
  echo "ERRORE: 'mc' (MinIO client) non trovato nel PATH." >&2
  exit 3
fi

count_objects() {  # $1 = alias/bucket
  mc ls --recursive "$1" 2>/dev/null | wc -l | tr -d ' '
}

echo "== migrate_minio_env_root =="
echo "sorgente=$SOURCE_ALIAS  destinazione=$TARGET_ALIAS  '$OLD_PREFIX' -> '$NEW_PREFIX'  apply=$APPLY"
echo

# Elenca i bucket sorgente che iniziano con OLD_PREFIX (ma non già col NEW_PREFIX).
mapfile -t BUCKETS < <(mc ls "$SOURCE_ALIAS" 2>/dev/null \
  | awk '{print $NF}' | sed 's#/$##' \
  | grep -E "^${OLD_PREFIX}" | grep -vE "^${NEW_PREFIX}" || true)

if [[ ${#BUCKETS[@]} -eq 0 ]]; then
  echo "Nessun bucket con prefisso '$OLD_PREFIX' da migrare."
  exit 0
fi

FAIL=0
for src in "${BUCKETS[@]}"; do
  schema="${src#"$OLD_PREFIX"}"
  dst="${NEW_PREFIX}${schema}"
  src_n=$(count_objects "$SOURCE_ALIAS/$src")

  if $APPLY; then
    echo "-> $src ($src_n oggetti)  =>  $dst"
    mc mb --ignore-existing "$TARGET_ALIAS/$dst"
    mc mirror --overwrite "$SOURCE_ALIAS/$src" "$TARGET_ALIAS/$dst"
    dst_n=$(count_objects "$TARGET_ALIAS/$dst")
    if [[ "$src_n" != "$dst_n" ]]; then
      echo "   ATTENZIONE: conteggio diverso dopo mirror (src=$src_n dst=$dst_n)" >&2
      FAIL=1
    else
      echo "   OK ($dst_n oggetti)"
    fi
  else
    if mc ls "$TARGET_ALIAS/$dst" >/dev/null 2>&1; then
      dst_n=$(count_objects "$TARGET_ALIAS/$dst")
    else
      dst_n="(bucket assente)"
    fi
    printf "   [DRY-RUN] %-32s src=%-6s dst=%s\n" "$src -> $dst" "$src_n" "$dst_n"
  fi
done

echo
if $APPLY; then
  echo "Migrazione completata. NON sono stati cancellati i bucket vecchi: rimuoverli con"
  echo "'mc rb --force $SOURCE_ALIAS/${OLD_PREFIX}<schema>' solo dopo una finestra di osservazione (>=1 settimana)."
  exit $FAIL
else
  echo "Dry-run: nessuna scrittura. Rilanciare con --apply per eseguire la copia."
fi
