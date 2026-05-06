---
description: Instala o cron diário do Startupz Briefing e gera o primeiro briefing.
argument-hint: "[hora] [minuto]"
---

# /startupz:setup

Configura o cron local (launchd) que vai gerar o briefing diariamente. Depois roda uma geração imediata pra você ter briefing já hoje.

## Args

- `$1` — hora (0-23). Default: 7.
- `$2` — minuto (0-59). Default: 0.

## Pré-checks

```bash
if ! command -v jq >/dev/null 2>&1; then
  echo "ERRO: jq não encontrado. Instale com: brew install jq"
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERRO: Claude Code CLI não encontrado no PATH. Verifique sua instalação."
  exit 1
fi
```

## Execução

```bash
HOUR="${1:-7}"
MINUTE="${2:-0}"
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"

echo "Instalando cron pra $HOUR:$(printf '%02d' "$MINUTE")..."
STARTUPZ_PLUGIN_PATH="$PLUGIN_PATH" bash "$PLUGIN_PATH/scripts/install-cron.sh" "$HOUR" "$MINUTE"

echo
echo "Gerando primeiro briefing (pode levar alguns segundos)..."
STARTUPZ_PLUGIN_PATH="$PLUGIN_PATH" bash "$PLUGIN_PATH/scripts/generate-briefing.sh"

echo
echo "Pronto. Amanhã às $HOUR:$(printf '%02d' "$MINUTE") seu briefing aparece sozinho ao abrir o Claude Code."
echo "Pra rodar manualmente: /startupz:morning"
echo "Pra desinstalar: /startupz:uninstall"
```
