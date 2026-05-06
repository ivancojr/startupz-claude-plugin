#!/usr/bin/env bash
# uninstall-cron.sh — remove o launchd job, mantém histórico de briefings.

set -euo pipefail

TARGET="$HOME/Library/LaunchAgents/co.startupz.briefing.plist"

if [ -f "$TARGET" ]; then
  launchctl unload "$TARGET" 2>/dev/null || true
  rm -f "$TARGET"
  echo "OK: cron removido. Histórico em ~/.startupz/briefings preservado."
else
  echo "OK: nenhum cron instalado."
fi
