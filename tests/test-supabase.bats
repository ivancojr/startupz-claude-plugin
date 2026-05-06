#!/usr/bin/env bats

setup() {
  source scripts/lib/fetch-startupz.sh
}

skip_if_no_network() {
  curl -sf --max-time 3 https://www.google.com >/dev/null 2>&1 || skip "sem rede"
}

@test "fetch_startupz_articles retorna JSON array" {
  skip_if_no_network
  result=$(fetch_startupz_articles 168)
  echo "$result" | jq empty
  echo "$result" | jq -e 'type == "array"'
}

@test "cada item tem campos esperados quando há conteúdo" {
  skip_if_no_network
  result=$(fetch_startupz_articles 720)
  count=$(echo "$result" | jq 'length')
  if [ "$count" -gt 0 ]; then
    echo "$result" | jq -e '.[0] | (.title and .slug and .published_at)'
  fi
}

@test "fetch_startupz_articles retorna [] em erro de rede" {
  STARTUPZ_SUPABASE_URL="https://invalid-host-xxx.example" \
    run fetch_startupz_articles 24
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}
