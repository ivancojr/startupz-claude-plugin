---
description: Exibe o briefing do dia. Se ainda não existe, gera agora.
---

# /startupz:morning

Exibe o briefing do dia. Se o cron ainda não rodou (máquina dormiu, etc.), gera sob demanda.

## Execução

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
TODAY=$(date +%Y-%m-%d)
BRIEFING="$HOME/.startupz/briefings/$TODAY.md"

if [ -f "$BRIEFING" ]; then
  cat "$BRIEFING"
else
  echo "Briefing de hoje ainda não foi gerado. Gerando agora..."
  echo
  STARTUPZ_PLUGIN_PATH="$PLUGIN_PATH" bash "$PLUGIN_PATH/scripts/generate-briefing.sh"
  echo
  cat "$BRIEFING"
fi
```
