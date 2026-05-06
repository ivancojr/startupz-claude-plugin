#!/usr/bin/env bash
# fetch-rss.sh — parser RSS para o briefing Startupz
# Funções:
#   parse_rss_file <path>            → JSON array com {title, link, pubDate, description}
#   fetch_rss_url <url>              → mesmo, mas baixa antes
#   filter_within_hours <h> [--now T] → filtra stdin pra itens com pubDate dentro de h horas

set -euo pipefail

parse_rss_file() {
  local file="$1"
  python3 -c '
import sys, re, json
with open("'"$file"'", "r", encoding="utf-8") as f:
    raw = f.read()
items = re.findall(r"<item>(.*?)</item>", raw, re.DOTALL)
out = []
for it in items:
    def grab(tag):
        m = re.search(rf"<{tag}>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</{tag}>", it, re.DOTALL)
        return m.group(1).strip() if m else ""
    out.append({
        "title": grab("title"),
        "link": grab("link"),
        "pubDate": grab("pubDate"),
        "description": grab("description")[:500],
    })
print(json.dumps(out, ensure_ascii=False))
'
}

fetch_rss_url() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  if ! curl -sfL --max-time 10 "$url" -o "$tmp"; then
    echo "[]"
    rm -f "$tmp"
    return 0
  fi
  parse_rss_file "$tmp"
  rm -f "$tmp"
}

filter_within_hours() {
  local hours="$1"; shift
  local now_iso=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --now) now_iso="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  HOURS="$hours" NOW_ISO="$now_iso" python3 -c "
import sys, json, os
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime

hours = int(os.environ['HOURS'])
now_iso = os.environ.get('NOW_ISO', '')
now = datetime.fromisoformat(now_iso) if now_iso else datetime.now(timezone.utc)
if now.tzinfo is None:
    now = now.replace(tzinfo=timezone.utc)

cutoff = now - timedelta(hours=hours)
items = json.load(sys.stdin)
out = []
for it in items:
    try:
        d = parsedate_to_datetime(it.get('pubDate',''))
        if d and d >= cutoff:
            out.append(it)
    except Exception:
        continue
print(json.dumps(out, ensure_ascii=False))
"
}
