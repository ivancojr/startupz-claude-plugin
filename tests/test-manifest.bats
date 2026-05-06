#!/usr/bin/env bats

@test "plugin.json é JSON válido" {
  run jq empty plugin.json
  [ "$status" -eq 0 ]
}

@test "plugin.json tem campos obrigatórios" {
  run jq -e '.name and .version and .description' plugin.json
  [ "$status" -eq 0 ]
}

@test "plugin.json declara commands, hooks e skills" {
  run jq -e '.commands and .hooks and .skills' plugin.json
  [ "$status" -eq 0 ]
}
