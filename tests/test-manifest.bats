#!/usr/bin/env bats

@test "plugin.json é JSON válido" {
  run jq empty .claude-plugin/plugin.json
  [ "$status" -eq 0 ]
}

@test "plugin.json tem campos obrigatórios" {
  run jq -e '.name and .version and .description' .claude-plugin/plugin.json
  [ "$status" -eq 0 ]
}

@test "plugin.json declara commands, hooks e skills" {
  run jq -e '.commands and .hooks and .skills' .claude-plugin/plugin.json
  [ "$status" -eq 0 ]
}

@test "marketplace.json é JSON válido" {
  run jq empty .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}

@test "marketplace.json registra o plugin com source ./" {
  run jq -e '.plugins[] | select(.name == "startupz-claude-plugin" and .source == "./")' .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}
