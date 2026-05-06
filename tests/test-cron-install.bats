#!/usr/bin/env bats

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  mkdir -p "$HOME/Library/LaunchAgents"
  export STARTUPZ_PLUGIN_PATH="$BATS_TEST_DIRNAME/.."
  STUB_DIR="$(mktemp -d)"
  cat > "$STUB_DIR/launchctl" <<'EOF'
#!/usr/bin/env bash
echo "stub-launchctl $@" >> "$HOME/.launchctl-calls.log"
exit 0
EOF
  chmod +x "$STUB_DIR/launchctl"
  export PATH="$STUB_DIR:$PATH"
}

teardown() {
  rm -rf "$TEST_HOME"
}

@test "install-cron.sh cria plist em ~/Library/LaunchAgents" {
  run bash "$STARTUPZ_PLUGIN_PATH/scripts/install-cron.sh" 7 0
  [ "$status" -eq 0 ]
  [ -f "$HOME/Library/LaunchAgents/co.startupz.briefing.plist" ]
}

@test "plist gerado é XML válido" {
  bash "$STARTUPZ_PLUGIN_PATH/scripts/install-cron.sh" 7 0
  run xmllint --noout "$HOME/Library/LaunchAgents/co.startupz.briefing.plist"
  [ "$status" -eq 0 ]
}

@test "plist tem hora/minuto corretos" {
  bash "$STARTUPZ_PLUGIN_PATH/scripts/install-cron.sh" 8 30
  grep -q '<integer>8</integer>' "$HOME/Library/LaunchAgents/co.startupz.briefing.plist"
  grep -q '<integer>30</integer>' "$HOME/Library/LaunchAgents/co.startupz.briefing.plist"
}

@test "install-cron.sh chama launchctl load" {
  bash "$STARTUPZ_PLUGIN_PATH/scripts/install-cron.sh" 7 0
  grep -q "load" "$HOME/.launchctl-calls.log"
}
