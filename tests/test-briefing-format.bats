#!/usr/bin/env bats

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  mkdir -p "$HOME/.startupz/briefings" "$HOME/.startupz/logs"
  export STARTUPZ_PLUGIN_PATH="$BATS_TEST_DIRNAME/.."
}

teardown() {
  rm -rf "$TEST_HOME"
}

@test "--dry-run não escreve briefing mas exibe payload no stderr" {
  run bash "$STARTUPZ_PLUGIN_PATH/scripts/generate-briefing.sh" --dry-run
  [ "$status" -eq 0 ]
  today=$(date +%Y-%m-%d)
  [ ! -f "$HOME/.startupz/briefings/$today.md" ]
}

@test "--no-llm gera fallback sem chamar claude" {
  run bash "$STARTUPZ_PLUGIN_PATH/scripts/generate-briefing.sh" --no-llm
  [ "$status" -eq 0 ]
  today=$(date +%Y-%m-%d)
  [ -f "$HOME/.startupz/briefings/$today.md" ]
  grep -q "# Briefing Startupz" "$HOME/.startupz/briefings/$today.md"
}

@test "regeneração faz backup do arquivo anterior" {
  bash "$STARTUPZ_PLUGIN_PATH/scripts/generate-briefing.sh" --no-llm
  today=$(date +%Y-%m-%d)
  [ -f "$HOME/.startupz/briefings/$today.md" ]
  bash "$STARTUPZ_PLUGIN_PATH/scripts/generate-briefing.sh" --no-llm
  [ -f "$HOME/.startupz/briefings/$today.md.bak" ]
}

@test "rotação de 30 dias deleta briefings antigos" {
  old=$(python3 -c "from datetime import date,timedelta; print(date.today()-timedelta(days=40))")
  touch -t $(date -v-40d +%Y%m%d0000) "$HOME/.startupz/briefings/${old}.md"
  bash "$STARTUPZ_PLUGIN_PATH/scripts/generate-briefing.sh" --no-llm
  [ ! -f "$HOME/.startupz/briefings/${old}.md" ]
}

@test "session-start exibe briefing do dia se existe" {
  today=$(date +%Y-%m-%d)
  echo "# Briefing Startupz — $today" > "$HOME/.startupz/briefings/$today.md"
  echo "conteudo de teste" >> "$HOME/.startupz/briefings/$today.md"
  run bash "$STARTUPZ_PLUGIN_PATH/hooks/session-start.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"conteudo de teste"* ]]
}

@test "session-start é silencioso se não há briefing" {
  run bash "$STARTUPZ_PLUGIN_PATH/hooks/session-start.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "session-start respeita flag .shown e não duplica" {
  today=$(date +%Y-%m-%d)
  echo "# Briefing" > "$HOME/.startupz/briefings/$today.md"
  bash "$STARTUPZ_PLUGIN_PATH/hooks/session-start.sh" >/dev/null
  run bash "$STARTUPZ_PLUGIN_PATH/hooks/session-start.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
