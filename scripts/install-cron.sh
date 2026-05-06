#!/usr/bin/env bash
# install-cron.sh <hour> <minute>
# Renderiza o template do plist e instala via launchctl.

set -euo pipefail

HOUR="${1:-7}"
MINUTE="${2:-0}"

PLUGIN_PATH="${STARTUPZ_PLUGIN_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
TEMPLATE="$PLUGIN_PATH/templates/co.startupz.briefing.plist.tmpl"
TARGET="$HOME/Library/LaunchAgents/co.startupz.briefing.plist"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template não encontrado em $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/.startupz/logs"
mkdir -p "$HOME/.startupz/briefings"

sed -e "s|__PLUGIN_PATH__|$PLUGIN_PATH|g" \
    -e "s|__HOME__|$HOME|g" \
    -e "s|__HOUR__|$HOUR|g" \
    -e "s|__MINUTE__|$MINUTE|g" \
    "$TEMPLATE" > "$TARGET"

if ! xmllint --noout "$TARGET" 2>/dev/null; then
  echo "ERROR: plist gerado é inválido" >&2
  exit 1
fi

launchctl unload "$TARGET" 2>/dev/null || true
launchctl load "$TARGET"

echo "OK: cron instalado pra rodar diariamente às ${HOUR}:$(printf '%02d' "$MINUTE")"
