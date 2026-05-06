---
description: Remove o cron diário. Mantém histórico de briefings em ~/.startupz/briefings.
---

# /startupz:uninstall

Remove o launchd job. Mantém todos os briefings antigos em `~/.startupz/briefings/` (pra apagar tudo, manualmente: `rm -rf ~/.startupz`).

## Execução

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
bash "$PLUGIN_PATH/scripts/uninstall-cron.sh"

echo
echo "Pra reinstalar: /startupz:setup"
echo "Pra remover histórico: rm -rf ~/.startupz"
```
