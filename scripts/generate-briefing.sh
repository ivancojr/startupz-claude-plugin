#!/usr/bin/env bash
# generate-briefing.sh — entrypoint do cron.
# Modos:
#   (default)   busca fontes, monta prompt, chama claude --print, salva briefing.
#   --dry-run   exibe payload no stderr, não chama LLM, não salva.
#   --no-llm    pula LLM, salva briefing fallback (manchetes raw).

set -euo pipefail

DRY_RUN=0
NO_LLM=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-llm)  NO_LLM=1 ;;
  esac
done

PLUGIN_PATH="${STARTUPZ_PLUGIN_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$PLUGIN_PATH/scripts/lib/fetch-rss.sh"
source "$PLUGIN_PATH/scripts/lib/fetch-startupz.sh"

TODAY=$(date +%Y-%m-%d)
BRIEFINGS_DIR="$HOME/.startupz/briefings"
LOGS_DIR="$HOME/.startupz/logs"
mkdir -p "$BRIEFINGS_DIR" "$LOGS_DIR"
LOG="$LOGS_DIR/$TODAY.log"
TARGET="$BRIEFINGS_DIR/$TODAY.md"

log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG" >&2; }

RSS_SOURCES=(
  "Brazil Journal|https://braziljournal.com/feed/"
  "Startupi|https://startupi.com.br/feed/"
  "Neofeed|https://www.neofeed.com.br/feed"
  "Pipeline Valor|https://valor.globo.com/pipeline/rss"
  "Startups.com.br|https://startups.com.br/feed/"
)

log "Iniciando geração do briefing $TODAY"

log "Buscando Startupz..."
STARTUPZ_JSON=$(fetch_startupz_articles 24 || echo "[]")
log "Startupz: $(echo "$STARTUPZ_JSON" | jq 'length') artigos"

RSS_JSON='[]'
for entry in "${RSS_SOURCES[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  log "Buscando $name..."
  items=$(fetch_rss_url "$url" | filter_within_hours 24)
  count=$(echo "$items" | jq 'length')
  log "$name: $count itens"
  RSS_JSON=$(jq -n --argjson agg "$RSS_JSON" --argjson items "$items" --arg src "$name" \
    '$agg + ($items | map(. + {source: $src}))')
done

PAYLOAD=$(jq -n \
  --argjson startupz "$STARTUPZ_JSON" \
  --argjson rss "$RSS_JSON" \
  --arg date "$TODAY" \
  '{date: $date, startupz: $startupz, ecossistema: $rss}')

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN — payload:"
  echo "$PAYLOAD" | jq . >&2
  exit 0
fi

if [ -f "$TARGET" ]; then
  cp "$TARGET" "$TARGET.bak"
  log "Backup de briefing anterior salvo em $TARGET.bak"
fi

if [ "$NO_LLM" -eq 1 ]; then
  log "Gerando fallback (--no-llm)..."
  {
    echo "# Briefing Startupz — $TODAY"
    echo
    echo "_Briefing fallback (sem síntese IA)._"
    echo
    echo "## Destaques do Startupz"
    echo "$STARTUPZ_JSON" | jq -r '.[] | "- [\(.title)](https://startupz.com.br/\(.slug)) — \(.excerpt // "")"'
    echo
    echo "## O que rolou no ecossistema BR"
    echo "$RSS_JSON" | jq -r '.[] | "- **\(.source):** [\(.title)](\(.link))"'
    echo
    echo "## Insights do dia"
    echo
    echo "Síntese indisponível hoje. Veja as manchetes acima."
  } > "$TARGET"
else
  log "Chamando claude --print..."
  PROMPT="Use a skill startupz-briefing pra gerar o briefing diário do ecossistema brasileiro de startups a partir do JSON abaixo. Saída: markdown puro, pronto pra exibir.

JSON:
$PAYLOAD"
  if ! claude --print --plugin-dir "$PLUGIN_PATH" --append-system-prompt-file "$PLUGIN_PATH/skills/startupz-briefing/SKILL.md" "$PROMPT" > "$TARGET" 2>>"$LOG"; then
    log "ERRO: claude --print falhou. Salvando fallback."
    bash "$0" --no-llm
    exit 1
  fi
fi

if [ -f "$TARGET.bak" ]; then
  TS=$(date +%H:%M)
  TMP="$(mktemp)"
  echo "<!-- regenerated at $TS -->" > "$TMP"
  cat "$TARGET" >> "$TMP"
  mv "$TMP" "$TARGET"
fi

find "$BRIEFINGS_DIR" -name '*.md' -mtime +30 -delete 2>/dev/null || true
find "$BRIEFINGS_DIR" -name '*.md.bak' -mtime +30 -delete 2>/dev/null || true

log "Briefing salvo em $TARGET ($(wc -w < "$TARGET") palavras)"
echo "$TARGET"
