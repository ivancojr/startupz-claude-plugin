#!/usr/bin/env bash
# smoke-e2e.sh — roda fluxo completo num HOME temporário.
# Não chama LLM real (--no-llm).

set -euo pipefail

TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"
PLUGIN_PATH=$(cd "$(dirname "$0")/.." && pwd)
export STARTUPZ_PLUGIN_PATH="$PLUGIN_PATH"

echo "=== HOME temp: $TMP_HOME ==="

STUB=$(mktemp -d)
cat > "$STUB/launchctl" <<'EOF'
#!/usr/bin/env bash
echo "[stub launchctl] $@"
exit 0
EOF
chmod +x "$STUB/launchctl"
export PATH="$STUB:$PATH"

echo "=== install-cron ==="
bash "$PLUGIN_PATH/scripts/install-cron.sh" 7 0

echo "=== generate (no-llm) ==="
bash "$PLUGIN_PATH/scripts/generate-briefing.sh" --no-llm

TODAY=$(date +%Y-%m-%d)
BRIEFING="$HOME/.startupz/briefings/$TODAY.md"
[ -f "$BRIEFING" ] || { echo "FAIL: briefing não gerado"; exit 1; }
echo "=== briefing ==="
cat "$BRIEFING"

echo "=== session-start (1ª vez: deve exibir) ==="
out1=$(bash "$PLUGIN_PATH/hooks/session-start.sh")
[ -n "$out1" ] || { echo "FAIL: hook silencioso na 1ª vez"; exit 1; }

echo "=== session-start (2ª vez: deve ser silencioso) ==="
out2=$(bash "$PLUGIN_PATH/hooks/session-start.sh")
[ -z "$out2" ] || { echo "FAIL: hook duplicou"; exit 1; }

echo "=== uninstall ==="
bash "$PLUGIN_PATH/scripts/uninstall-cron.sh"
[ ! -f "$HOME/Library/LaunchAgents/co.startupz.briefing.plist" ] || { echo "FAIL: plist persistiu"; exit 1; }

echo
echo "=== TODOS OS PASSOS PASSARAM ==="
rm -rf "$TMP_HOME" "$STUB"
