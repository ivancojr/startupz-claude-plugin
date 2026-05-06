#!/usr/bin/env bats

setup() {
  source scripts/lib/fetch-rss.sh
}

skip_if_no_network() {
  curl -sf --max-time 3 https://www.google.com >/dev/null 2>&1 || skip "sem rede"
}

@test "parse_rss_file extrai title, link e pubDate de cada item" {
  result=$(parse_rss_file tests/fixtures/sample-feed.xml)
  echo "$result" | jq -e 'length == 2'
  echo "$result" | jq -e '.[0].title == "Startup X levanta R$ 50mi"'
  echo "$result" | jq -e '.[0].link == "https://braziljournal.com/post-1"'
  echo "$result" | jq -e '.[0].pubDate'
}

@test "filter_within_hours mantém apenas itens dentro da janela" {
  items=$(parse_rss_file tests/fixtures/sample-feed.xml)
  # janela enorme: ambos passam
  count=$(echo "$items" | filter_within_hours 9999999 | jq 'length')
  [ "$count" -eq 2 ]
  # janela 24h relativa a 2026-05-06: só o item recente passa (o de 2024 não)
  count=$(echo "$items" | filter_within_hours 24 --now "2026-05-06T12:00:00-0300" | jq 'length')
  [ "$count" -eq 1 ]
}

@test "fetch_rss_url retorna JSON válido (smoke, requer rede)" {
  skip_if_no_network
  result=$(fetch_rss_url "https://startupi.com.br/feed/")
  echo "$result" | jq empty
}
