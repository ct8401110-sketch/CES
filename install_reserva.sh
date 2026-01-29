#!/usr/bin/env bash

# Script de reserva para executar o instalador principal (A.sh)
# Uso: sudo ./install_reserva.sh

set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$ROOT_DIR/A.sh"
LOG="$HOME/bootstrap-install-reserva-$(date +%Y%m%d-%H%M%S).log"

if [ ! -f "$SCRIPT" ]; then
  echo "Arquivo A.sh não encontrado em: $SCRIPT" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Necessita de privilégios de superusuário. Tentando com sudo..."
  exec sudo bash "$0" "$@"
fi

echo "Executando $SCRIPT (logs em $LOG)"
bash "$SCRIPT" "$@" 2>&1 | tee -a "$LOG"

EXIT=${PIPESTATUS[0]:-0}
if [ "$EXIT" -ne 0 ]; then
  echo "A execução terminou com código $EXIT. Verifique o log: $LOG" >&2
  exit "$EXIT"
fi

echo "Instalação concluída com sucesso. Log: $LOG"
