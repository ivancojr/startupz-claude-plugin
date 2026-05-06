#!/usr/bin/env bash
# fetch-startupz.sh — busca artigos publicados no Supabase do Startupz
# Função:
#   fetch_startupz_articles <hours_window>  → JSON array com artigos publicados na janela

set -euo pipefail

: "${STARTUPZ_SUPABASE_URL:=https://vfntyqijlrdlgcponeez.supabase.co}"
: "${STARTUPZ_SUPABASE_ANON_KEY:=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmbnR5cWlqbHJkbGdjcG9uZWV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNTg3NDUsImV4cCI6MjA4MDgzNDc0NX0.zyyjWLAz1yGMBIWllFHl7RfGtDDkg9y5sI_bVpnkj5o}"

fetch_startupz_articles() {
  local hours="$1"
  local cutoff
  cutoff=$(HOURS="$hours" python3 -c "
import os
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) - timedelta(hours=int(os.environ['HOURS']))).strftime('%Y-%m-%dT%H:%M:%S+00:00'))
")
  local url="${STARTUPZ_SUPABASE_URL}/rest/v1/articles?select=title,slug,excerpt,category,published_at,author_name&published=eq.true&published_at=gte.${cutoff}&order=published_at.desc&limit=10"

  local response
  response=$(curl -sfL --max-time 10 \
    -H "apikey: ${STARTUPZ_SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${STARTUPZ_SUPABASE_ANON_KEY}" \
    "$url" 2>/dev/null) || { echo "[]"; return 0; }

  if echo "$response" | jq empty 2>/dev/null; then
    echo "$response"
  else
    echo "[]"
  fi
}
