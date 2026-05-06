#!/usr/bin/env bash
# session-start.sh — exibe o briefing do dia na primeira sessão.

set -e

TODAY=$(date +%Y-%m-%d)
BRIEFING="$HOME/.startupz/briefings/$TODAY.md"
FLAG="$HOME/.startupz/.shown-$TODAY"

[ -f "$FLAG" ] && exit 0
[ ! -f "$BRIEFING" ] && exit 0

cat "$BRIEFING"
mkdir -p "$HOME/.startupz"
touch "$FLAG"

find "$HOME/.startupz" -maxdepth 1 -name '.shown-*' -mtime +7 -delete 2>/dev/null || true
