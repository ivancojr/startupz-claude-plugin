# Startupz Claude Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir o plugin `startupz-claude-plugin` que entrega um briefing diário do ecossistema brasileiro de startups via cron local (launchd) e SessionStart hook do Claude Code.

**Architecture:** Plugin Claude Code com slash commands de instalação/setup/uninstall, hook SessionStart, skill interna `startupz-briefing`, e scripts bash que orquestram fetch de fontes (Supabase Startupz + 5 RSS BR), montagem de prompt e chamada de `claude --print` pra gerar o markdown do briefing. Persistência em `~/.startupz/briefings/YYYY-MM-DD.md`. Cron via `launchd` com plist em `~/Library/LaunchAgents`.

**Tech Stack:** Bash 4+, `curl`, `jq`, `xmllint`, `launchctl`, `bats-core` (testing), Claude Code CLI (`claude --print`), Supabase REST.

---

## File Structure

```
startupz-claude-plugin/
├── plugin.json                              # plugin manifest
├── README.md                                # user-facing onboarding
├── .gitignore
├── commands/
│   ├── setup.md                             # /startupz:setup
│   ├── morning.md                           # /startupz:morning
│   └── uninstall.md                         # /startupz:uninstall
├── hooks/
│   └── session-start.sh                     # exibe briefing do dia
├── skills/
│   └── startupz-briefing/
│       └── SKILL.md                         # tom + estrutura do briefing
├── scripts/
│   ├── generate-briefing.sh                 # entrypoint do cron
│   ├── install-cron.sh
│   ├── uninstall-cron.sh
│   └── lib/
│       ├── fetch-rss.sh                     # parse RSS de uma URL
│       └── fetch-startupz.sh                # query Supabase Startupz
├── templates/
│   └── co.startupz.briefing.plist.tmpl      # template do launchd plist
└── tests/
    ├── helpers/
    │   └── load-bats.bash
    ├── fixtures/
    │   └── sample-feed.xml
    ├── test-rss-fetch.bats
    ├── test-supabase.bats
    ├── test-briefing-format.bats
    └── test-cron-install.bats
```

---

### Task 1: Bootstrap do repositório

**Files:**
- Create: `/Users/Ivan/startupz-claude-plugin/.gitignore`
- Create: `/Users/Ivan/startupz-claude-plugin/README.md` (placeholder, conteúdo final na Task 14)
- Create: `/Users/Ivan/startupz-claude-plugin/.bats/.keep`

- [ ] **Step 1: Criar `.gitignore`**

```
# Test artifacts
tests/.tmp/
tests/output/

# Local dev
~/.startupz/
.DS_Store

# Logs
*.log

# Editor
.vscode/
.idea/
```

- [ ] **Step 2: Criar README placeholder**

```markdown
# Startupz Claude Plugin

Briefing diário do ecossistema brasileiro de startups, direto no Claude Code.

> Em construção. README final será adicionado na Task 14.
```

- [ ] **Step 3: Verificar bats-core instalado (dependency check)**

Run: `which bats || brew install bats-core`
Expected: caminho do bats ou instalação bem-sucedida.

- [ ] **Step 4: Commit**

```bash
cd /Users/Ivan/startupz-claude-plugin
git add .gitignore README.md
git commit -m "chore: bootstrap plugin repo with gitignore and placeholder readme"
```

---

### Task 2: plugin.json manifest

**Files:**
- Create: `plugin.json`

- [ ] **Step 1: Escrever teste — manifest válido**

Create `tests/test-manifest.bats`:
```bash
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
```

- [ ] **Step 2: Rodar teste pra verificar falha**

Run: `bats tests/test-manifest.bats`
Expected: 3 failures (arquivo `plugin.json` não existe).

- [ ] **Step 3: Criar `plugin.json`**

```json
{
  "name": "startupz-claude-plugin",
  "version": "0.1.0",
  "description": "Briefing diário do ecossistema brasileiro de startups direto no Claude Code, com Startupz como âncora editorial.",
  "author": {
    "name": "Startupz",
    "url": "https://startupz.com.br"
  },
  "homepage": "https://github.com/ivancojr/startupz-claude-plugin",
  "commands": [
    "commands/setup.md",
    "commands/morning.md",
    "commands/uninstall.md"
  ],
  "hooks": {
    "SessionStart": "hooks/session-start.sh"
  },
  "skills": [
    "skills/startupz-briefing"
  ]
}
```

- [ ] **Step 4: Rodar teste pra verificar passa**

Run: `bats tests/test-manifest.bats`
Expected: 3 passing.

- [ ] **Step 5: Commit**

```bash
git add plugin.json tests/test-manifest.bats
git commit -m "feat: add plugin.json manifest with commands, hooks, and skills declaration"
```

---

### Task 3: Lib `fetch-rss.sh` (parser RSS)

**Files:**
- Create: `scripts/lib/fetch-rss.sh`
- Create: `tests/fixtures/sample-feed.xml`
- Create: `tests/test-rss-fetch.bats`

- [ ] **Step 1: Criar fixture de feed RSS**

Create `tests/fixtures/sample-feed.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Brazil Journal Test</title>
    <link>https://braziljournal.com</link>
    <item>
      <title>Startup X levanta R$ 50mi</title>
      <link>https://braziljournal.com/post-1</link>
      <pubDate>Wed, 06 May 2026 09:00:00 -0300</pubDate>
      <description><![CDATA[<p>Lorem ipsum sobre fundraising.</p>]]></description>
    </item>
    <item>
      <title>Notícia velha</title>
      <link>https://braziljournal.com/post-old</link>
      <pubDate>Mon, 01 Jan 2024 09:00:00 -0300</pubDate>
      <description>Antiga.</description>
    </item>
  </channel>
</rss>
```

- [ ] **Step 2: Escrever testes**

Create `tests/test-rss-fetch.bats`:
```bash
#!/usr/bin/env bats

setup() {
  source scripts/lib/fetch-rss.sh
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

skip_if_no_network() {
  curl -sf --max-time 3 https://www.google.com >/dev/null 2>&1 || skip "sem rede"
}
```

- [ ] **Step 3: Rodar teste pra verificar falha**

Run: `bats tests/test-rss-fetch.bats`
Expected: failures (script ainda não existe).

- [ ] **Step 4: Implementar `scripts/lib/fetch-rss.sh`**

```bash
#!/usr/bin/env bash
# fetch-rss.sh — parser RSS para o briefing Startupz
# Funções:
#   parse_rss_file <path>            → JSON array com {title, link, pubDate, description}
#   fetch_rss_url <url>              → mesmo, mas baixa antes
#   filter_within_hours <h> [--now T] → filtra stdin pra itens com pubDate dentro de h horas

set -euo pipefail

parse_rss_file() {
  local file="$1"
  xmllint --xpath '//item' "$file" 2>/dev/null \
    | sed 's|<item>|\n<item>|g' \
    | awk '/<item>/,/<\/item>/' \
    | python3 -c '
import sys, re, json
raw = sys.stdin.read()
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
  python3 -c "
import sys, json
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime

hours = int('$hours')
now_iso = '$now_iso'
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
```

- [ ] **Step 5: Rodar teste pra verificar passa**

Run: `bats tests/test-rss-fetch.bats`
Expected: 3 passing (ou 2 + 1 skipped se sem rede).

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/fetch-rss.sh tests/test-rss-fetch.bats tests/fixtures/sample-feed.xml
git commit -m "feat: add fetch-rss.sh lib with parse, fetch, and time-window filter"
```

---

### Task 4: Lib `fetch-startupz.sh` (Supabase REST)

**Files:**
- Create: `scripts/lib/fetch-startupz.sh`
- Create: `tests/test-supabase.bats`

- [ ] **Step 1: Escrever testes**

Create `tests/test-supabase.bats`:
```bash
#!/usr/bin/env bats

setup() {
  source scripts/lib/fetch-startupz.sh
}

skip_if_no_network() {
  curl -sf --max-time 3 https://www.google.com >/dev/null 2>&1 || skip "sem rede"
}

@test "fetch_startupz_articles retorna JSON array" {
  skip_if_no_network
  result=$(fetch_startupz_articles 168)  # 7 dias
  echo "$result" | jq empty
  echo "$result" | jq -e 'type == "array"'
}

@test "cada item tem campos esperados quando há conteúdo" {
  skip_if_no_network
  result=$(fetch_startupz_articles 720)  # 30 dias pra garantir ≥1 item
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
```

- [ ] **Step 2: Rodar teste pra verificar falha**

Run: `bats tests/test-supabase.bats`
Expected: failures (script não existe).

- [ ] **Step 3: Implementar `scripts/lib/fetch-startupz.sh`**

```bash
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
  cutoff=$(python3 -c "
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) - timedelta(hours=int('$hours'))).strftime('%Y-%m-%dT%H:%M:%S+00:00'))
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
```

- [ ] **Step 4: Rodar teste pra verificar passa**

Run: `bats tests/test-supabase.bats`
Expected: 3 passing (ou skips se sem rede).

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/fetch-startupz.sh tests/test-supabase.bats
git commit -m "feat: add fetch-startupz.sh lib for Supabase REST queries"
```

---

### Task 5: Skill `startupz-briefing/SKILL.md`

**Files:**
- Create: `skills/startupz-briefing/SKILL.md`

- [ ] **Step 1: Criar SKILL.md**

```markdown
---
name: startupz-briefing
description: Gera o briefing diário do ecossistema brasileiro de startups com tom Startupz. Use quando o pipeline de geração (scripts/generate-briefing.sh) chamar via claude --print.
---

# Startupz Briefing

Você está gerando o briefing diário do ecossistema brasileiro de startups. O input é um JSON com itens coletados do Startupz e de fontes externas BR. Sua saída é um markdown completo de ~1500 palavras seguindo a estrutura abaixo.

## Estrutura obrigatória

Sempre exatamente 3 blocos, nessa ordem:

```markdown
# Briefing Startupz — {data}

## Destaques do Startupz
[3-5 artigos. Para cada: ## subheader com título, 1 parágrafo com excerpt + contexto, link.]

## O que rolou no ecossistema BR
[5-8 manchetes. Cada uma: 1-2 frases + fonte (link).]

## Insights do dia
[~400 palavras. Análise conectando 2-3 itens. Tendência observada. Termina com "o que isso significa pra empreendedores BR" — pragmático, acionável.]
```

Se um bloco fica vazio (ex: Startupz sem publicação), insira nota curta — **não esconda a seção**.

## Tom

- **Direto, founder-to-founder.** Português brasileiro neutro.
- **Sem clichês de newsletter:** "imperdível", "você não pode perder", "fique por dentro", "confira".
- **Sem emojis no corpo.** Header pode ter um (📰).
- **Sem self-references** ao Claude, IA, modelo, Anthropic, OpenAI ou qualquer ferramenta. Você é a voz editorial do Startupz.

## Insights — o que faz um bom insight

**Bom:**
> Três rounds de fintech B2B esta semana mostram que o capital ainda fluí pra infra de pagamentos, não pra UX consumer. Pra fundadores: se sua tese é embedded finance, o ar tá rarefeito; se é rails ou compliance, tem fila de fundo.

**Ruim:**
> O ecossistema brasileiro continua dinâmico e cheio de oportunidades. Vários setores cresceram esta semana, o que mostra a força do empreendedorismo nacional.

A diferença: insight bom **observa um padrão concreto**, **conecta a uma decisão**, **não decora**.

## Restrições

- **Sem inventar dados.** Se o item da fonte não tem número/detalhe, não fabrique. Use linguagem condicional ("teria levantado", "segundo o Brazil Journal").
- **Toda manchete tem link.** Toda análise referencia itens específicos pelo título.
- **Tamanho:** ~1500 palavras totais. Insights ~400, restante distribuído.
- **Sem repetir o mesmo item** em blocos diferentes (Destaques vs Ecossistema).
```

- [ ] **Step 2: Validar que o frontmatter parseia**

Run: `head -5 skills/startupz-briefing/SKILL.md | grep -q '^name: startupz-briefing'`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add skills/startupz-briefing/SKILL.md
git commit -m "feat: add startupz-briefing skill with tone, structure, and constraints"
```

---

### Task 6: Template plist do launchd

**Files:**
- Create: `templates/co.startupz.briefing.plist.tmpl`

- [ ] **Step 1: Criar template**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>co.startupz.briefing</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>__PLUGIN_PATH__/scripts/generate-briefing.sh</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>__HOUR__</integer>
        <key>Minute</key>
        <integer>__MINUTE__</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>__HOME__/.startupz/logs/launchd-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>__HOME__/.startupz/logs/launchd-stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>HOME</key>
        <string>__HOME__</string>
        <key>STARTUPZ_PLUGIN_PATH</key>
        <string>__PLUGIN_PATH__</string>
    </dict>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 2: Commit**

```bash
git add templates/co.startupz.briefing.plist.tmpl
git commit -m "feat: add launchd plist template with placeholders for hour/minute/path"
```

---

### Task 7: Script `install-cron.sh`

**Files:**
- Create: `scripts/install-cron.sh`
- Create: `tests/test-cron-install.bats`

- [ ] **Step 1: Escrever testes**

Create `tests/test-cron-install.bats`:
```bash
#!/usr/bin/env bats

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  mkdir -p "$HOME/Library/LaunchAgents"
  export STARTUPZ_PLUGIN_PATH="$BATS_TEST_DIRNAME/.."
  # Stub launchctl pra não tocar no sistema real
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
```

- [ ] **Step 2: Rodar teste pra verificar falha**

Run: `bats tests/test-cron-install.bats`
Expected: failures (script não existe).

- [ ] **Step 3: Implementar `scripts/install-cron.sh`**

```bash
#!/usr/bin/env bash
# install-cron.sh <hour> <minute>
# Renderiza o template do plist e instala via launchctl.

set -euo pipefail

HOUR="${1:-7}"
MINUTE="${2:-0}"

PLUGIN_PATH="${STARTUPZ_PLUGIN_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
TEMPLATE="$PLUGIN_PATH/templates/co.startupz.briefing.plist.tmpl"
TARGET="$HOME/Library/LaunchAgents/co.startupz.briefing.plist"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template não encontrado em $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/.startupz/logs"
mkdir -p "$HOME/.startupz/briefings"

# Renderiza template
sed -e "s|__PLUGIN_PATH__|$PLUGIN_PATH|g" \
    -e "s|__HOME__|$HOME|g" \
    -e "s|__HOUR__|$HOUR|g" \
    -e "s|__MINUTE__|$MINUTE|g" \
    "$TEMPLATE" > "$TARGET"

# Validate XML
if ! xmllint --noout "$TARGET" 2>/dev/null; then
  echo "ERROR: plist gerado é inválido" >&2
  exit 1
fi

# Load no launchd (idempotente: unload antes)
launchctl unload "$TARGET" 2>/dev/null || true
launchctl load "$TARGET"

echo "OK: cron instalado pra rodar diariamente às ${HOUR}:$(printf '%02d' "$MINUTE")"
```

- [ ] **Step 4: Tornar executável e rodar teste**

```bash
chmod +x scripts/install-cron.sh
bats tests/test-cron-install.bats
```
Expected: 4 passing.

- [ ] **Step 5: Commit**

```bash
git add scripts/install-cron.sh tests/test-cron-install.bats
git commit -m "feat: add install-cron.sh that renders plist template and loads via launchctl"
```

---

### Task 8: Script `uninstall-cron.sh`

**Files:**
- Create: `scripts/uninstall-cron.sh`

- [ ] **Step 1: Adicionar teste em `tests/test-cron-install.bats`**

Append:
```bash
@test "uninstall-cron.sh remove plist e chama unload" {
  bash "$STARTUPZ_PLUGIN_PATH/scripts/install-cron.sh" 7 0
  [ -f "$HOME/Library/LaunchAgents/co.startupz.briefing.plist" ]
  run bash "$STARTUPZ_PLUGIN_PATH/scripts/uninstall-cron.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/Library/LaunchAgents/co.startupz.briefing.plist" ]
  grep -q "unload" "$HOME/.launchctl-calls.log"
}

@test "uninstall-cron.sh é idempotente (sem plist instalado)" {
  run bash "$STARTUPZ_PLUGIN_PATH/scripts/uninstall-cron.sh"
  [ "$status" -eq 0 ]
}

@test "uninstall-cron.sh preserva ~/.startupz/briefings" {
  bash "$STARTUPZ_PLUGIN_PATH/scripts/install-cron.sh" 7 0
  echo "test" > "$HOME/.startupz/briefings/2026-05-06.md"
  bash "$STARTUPZ_PLUGIN_PATH/scripts/uninstall-cron.sh"
  [ -f "$HOME/.startupz/briefings/2026-05-06.md" ]
}
```

- [ ] **Step 2: Rodar — falham**

Run: `bats tests/test-cron-install.bats`
Expected: 3 novas failures.

- [ ] **Step 3: Implementar `scripts/uninstall-cron.sh`**

```bash
#!/usr/bin/env bash
# uninstall-cron.sh — remove o launchd job, mantém histórico de briefings.

set -euo pipefail

TARGET="$HOME/Library/LaunchAgents/co.startupz.briefing.plist"

if [ -f "$TARGET" ]; then
  launchctl unload "$TARGET" 2>/dev/null || true
  rm -f "$TARGET"
  echo "OK: cron removido. Histórico em ~/.startupz/briefings preservado."
else
  echo "OK: nenhum cron instalado."
fi
```

- [ ] **Step 4: Tornar executável e rodar testes**

```bash
chmod +x scripts/uninstall-cron.sh
bats tests/test-cron-install.bats
```
Expected: todos passing.

- [ ] **Step 5: Commit**

```bash
git add scripts/uninstall-cron.sh tests/test-cron-install.bats
git commit -m "feat: add uninstall-cron.sh that removes plist and preserves briefing history"
```

---

### Task 9: Script `generate-briefing.sh` (orquestrador)

**Files:**
- Create: `scripts/generate-briefing.sh`
- Create: `tests/test-briefing-format.bats`

- [ ] **Step 1: Escrever testes**

Create `tests/test-briefing-format.bats`:
```bash
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

@test "--dry-run não escreve briefing mas exibe prompt no stderr" {
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
  # Cria briefing antigo (40 dias atrás)
  old=$(python3 -c "from datetime import date,timedelta; print(date.today()-timedelta(days=40))")
  touch "$HOME/.startupz/briefings/${old}.md"
  bash "$STARTUPZ_PLUGIN_PATH/scripts/generate-briefing.sh" --no-llm
  [ ! -f "$HOME/.startupz/briefings/${old}.md" ]
}
```

- [ ] **Step 2: Rodar — falham**

Run: `bats tests/test-briefing-format.bats`
Expected: 4 failures.

- [ ] **Step 3: Implementar `scripts/generate-briefing.sh`**

```bash
#!/usr/bin/env bash
# generate-briefing.sh — entrypoint do cron.
# Modos:
#   (default)   busca fontes, monta prompt, chama claude --print, salva briefing.
#   --dry-run   exibe prompt no stderr, não chama LLM, não salva.
#   --no-llm    pula LLM, salva briefing fallback (manchetes raw).

set -euo pipefail

DRY_RUN=0
NO_LLM=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-llm)  NO_LLM=1 ;;
  esac
done

PLUGIN_PATH="${STARTUPZ_PLUGIN_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$PLUGIN_PATH/scripts/lib/fetch-rss.sh"
source "$PLUGIN_PATH/scripts/lib/fetch-startupz.sh"

TODAY=$(date +%Y-%m-%d)
BRIEFINGS_DIR="$HOME/.startupz/briefings"
LOGS_DIR="$HOME/.startupz/logs"
mkdir -p "$BRIEFINGS_DIR" "$LOGS_DIR"
LOG="$LOGS_DIR/$TODAY.log"
TARGET="$BRIEFINGS_DIR/$TODAY.md"

log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG" >&2; }

# Fontes RSS (hardcoded no MVP — futura config em ~/.startupz/config.json)
RSS_SOURCES=(
  "Brazil Journal|https://braziljournal.com/feed/"
  "Startupi|https://startupi.com.br/feed/"
  "Neofeed|https://www.neofeed.com.br/feed"
  "Pipeline Valor|https://valor.globo.com/pipeline/rss"
  "Startups.com.br|https://startups.com.br/feed/"
)

log "Iniciando geração do briefing $TODAY"

# Coleta Startupz
log "Buscando Startupz..."
STARTUPZ_JSON=$(fetch_startupz_articles 24 || echo "[]")
log "Startupz: $(echo "$STARTUPZ_JSON" | jq 'length') artigos"

# Coleta RSS
RSS_JSON='[]'
for entry in "${RSS_SOURCES[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  log "Buscando $name..."
  items=$(fetch_rss_url "$url" | filter_within_hours 24)
  count=$(echo "$items" | jq 'length')
  log "$name: $count itens"
  RSS_JSON=$(jq -n --argjson agg "$RSS_JSON" --argjson items "$items" --arg src "$name" \
    '$agg + ($items | map(. + {source: $src}))')
done

# Monta payload pro modelo
PAYLOAD=$(jq -n \
  --argjson startupz "$STARTUPZ_JSON" \
  --argjson rss "$RSS_JSON" \
  --arg date "$TODAY" \
  '{date: $date, startupz: $startupz, ecossistema: $rss}')

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN — payload:"
  echo "$PAYLOAD" | jq . >&2
  exit 0
fi

# Backup se já existe
if [ -f "$TARGET" ]; then
  cp "$TARGET" "$TARGET.bak"
  log "Backup de briefing anterior salvo em $TARGET.bak"
fi

# Geração
if [ "$NO_LLM" -eq 1 ]; then
  log "Gerando fallback (--no-llm)..."
  {
    echo "# Briefing Startupz — $TODAY"
    echo
    echo "_Briefing fallback (sem síntese IA)._"
    echo
    echo "## Destaques do Startupz"
    echo "$STARTUPZ_JSON" | jq -r '.[] | "- [\(.title)](https://startupz.com.br/\(.slug)) — \(.excerpt // "")"'
    echo
    echo "## O que rolou no ecossistema BR"
    echo "$RSS_JSON" | jq -r '.[] | "- **\(.source):** [\(.title)](\(.link))"'
    echo
    echo "## Insights do dia"
    echo
    echo "Síntese indisponível hoje. Veja as manchetes acima."
  } > "$TARGET"
else
  log "Chamando claude --print..."
  if ! echo "$PAYLOAD" | claude --print --skill startupz-briefing > "$TARGET" 2>>"$LOG"; then
    log "ERRO: claude --print falhou. Salvando fallback."
    bash "$0" --no-llm
    exit 1
  fi
fi

# Marcador de regeneração
if [ -f "$TARGET.bak" ]; then
  TS=$(date +%H:%M)
  TMP="$(mktemp)"
  echo "<!-- regenerated at $TS -->" > "$TMP"
  cat "$TARGET" >> "$TMP"
  mv "$TMP" "$TARGET"
fi

# Rotação 30 dias
find "$BRIEFINGS_DIR" -name '*.md' -mtime +30 -delete 2>/dev/null || true
find "$BRIEFINGS_DIR" -name '*.md.bak' -mtime +30 -delete 2>/dev/null || true

log "Briefing salvo em $TARGET ($(wc -w < "$TARGET") palavras)"
echo "$TARGET"
```

- [ ] **Step 4: Tornar executável e rodar testes**

```bash
chmod +x scripts/generate-briefing.sh
bats tests/test-briefing-format.bats
```
Expected: 4 passing.

- [ ] **Step 5: Smoke manual**

```bash
STARTUPZ_PLUGIN_PATH=$PWD bash scripts/generate-briefing.sh --dry-run
```
Expected: imprime JSON de payload no stderr, não cria arquivo.

- [ ] **Step 6: Commit**

```bash
git add scripts/generate-briefing.sh tests/test-briefing-format.bats
git commit -m "feat: add generate-briefing.sh orchestrator with dry-run, no-llm, and rotation"
```

---

### Task 10: SessionStart hook

**Files:**
- Create: `hooks/session-start.sh`

- [ ] **Step 1: Adicionar testes em `tests/test-briefing-format.bats`**

Append:
```bash
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
```

- [ ] **Step 2: Rodar — falham**

Run: `bats tests/test-briefing-format.bats`
Expected: 3 novas failures.

- [ ] **Step 3: Implementar `hooks/session-start.sh`**

```bash
#!/usr/bin/env bash
# session-start.sh — exibe o briefing do dia na primeira sessão.

set -e

TODAY=$(date +%Y-%m-%d)
BRIEFING="$HOME/.startupz/briefings/$TODAY.md"
FLAG="$HOME/.startupz/.shown-$TODAY"

[ -f "$FLAG" ] && exit 0
[ ! -f "$BRIEFING" ] && exit 0

cat "$BRIEFING"
mkdir -p "$HOME/.startupz"
touch "$FLAG"

# Limpa flags antigas (> 7 dias)
find "$HOME/.startupz" -maxdepth 1 -name '.shown-*' -mtime +7 -delete 2>/dev/null || true
```

- [ ] **Step 4: Tornar executável e rodar testes**

```bash
chmod +x hooks/session-start.sh
bats tests/test-briefing-format.bats
```
Expected: todos passing.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start.sh tests/test-briefing-format.bats
git commit -m "feat: add SessionStart hook that displays daily briefing once per day"
```

---

### Task 11: Slash command `/startupz:setup`

**Files:**
- Create: `commands/setup.md`

- [ ] **Step 1: Criar `commands/setup.md`**

```markdown
---
description: Instala o cron diário do Startupz Briefing e gera o primeiro briefing.
argument-hint: "[hora] [minuto]"
---

# /startupz:setup

Configura o cron local (launchd) que vai gerar o briefing diariamente. Depois roda uma geração imediata pra você ter briefing já hoje.

## Args

- `$1` — hora (0-23). Default: 7.
- `$2` — minuto (0-59). Default: 0.

## Pré-checks

1. Verifica se `jq` está instalado:
   ```bash
   if ! command -v jq >/dev/null 2>&1; then
     echo "ERRO: jq não encontrado. Instale com: brew install jq"
     exit 1
   fi
   ```

2. Verifica se `claude` está no PATH:
   ```bash
   if ! command -v claude >/dev/null 2>&1; then
     echo "ERRO: Claude Code CLI não encontrado no PATH. Verifique sua instalação."
     exit 1
   fi
   ```

## Execução

```bash
HOUR="${1:-7}"
MINUTE="${2:-0}"
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"

echo "Instalando cron pra $HOUR:$(printf '%02d' "$MINUTE")..."
STARTUPZ_PLUGIN_PATH="$PLUGIN_PATH" bash "$PLUGIN_PATH/scripts/install-cron.sh" "$HOUR" "$MINUTE"

echo
echo "Gerando primeiro briefing (pode levar alguns segundos)..."
STARTUPZ_PLUGIN_PATH="$PLUGIN_PATH" bash "$PLUGIN_PATH/scripts/generate-briefing.sh"

echo
echo "Pronto. Amanhã às $HOUR:$(printf '%02d' "$MINUTE") seu briefing aparece sozinho ao abrir o Claude Code."
echo "Pra rodar manualmente: /startupz:morning"
echo "Pra desinstalar: /startupz:uninstall"
```
```

- [ ] **Step 2: Commit**

```bash
git add commands/setup.md
git commit -m "feat: add /startupz:setup slash command"
```

---

### Task 12: Slash command `/startupz:morning`

**Files:**
- Create: `commands/morning.md`

- [ ] **Step 1: Criar `commands/morning.md`**

```markdown
---
description: Exibe o briefing do dia. Se ainda não existe, gera agora.
---

# /startupz:morning

Exibe o briefing do dia. Se o cron ainda não rodou (máquina dormiu, etc.), gera sob demanda.

## Execução

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
TODAY=$(date +%Y-%m-%d)
BRIEFING="$HOME/.startupz/briefings/$TODAY.md"

if [ -f "$BRIEFING" ]; then
  cat "$BRIEFING"
else
  echo "Briefing de hoje ainda não foi gerado. Gerando agora..."
  echo
  STARTUPZ_PLUGIN_PATH="$PLUGIN_PATH" bash "$PLUGIN_PATH/scripts/generate-briefing.sh"
  echo
  cat "$BRIEFING"
fi
```
```

- [ ] **Step 2: Commit**

```bash
git add commands/morning.md
git commit -m "feat: add /startupz:morning slash command for on-demand briefing display"
```

---

### Task 13: Slash command `/startupz:uninstall`

**Files:**
- Create: `commands/uninstall.md`

- [ ] **Step 1: Criar `commands/uninstall.md`**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add commands/uninstall.md
git commit -m "feat: add /startupz:uninstall slash command"
```

---

### Task 14: README de onboarding

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Reescrever `README.md`**

```markdown
# Startupz Claude Plugin

Briefing diário do ecossistema brasileiro de startups, direto no seu Claude Code.

Todo dia de manhã, você abre o Claude e o briefing já está lá: 3 destaques do **Startupz**, 5-8 manchetes do ecossistema BR (Brazil Journal, Startupi, Neofeed, Pipeline Valor, Startups.com.br), e um bloco de **insights do dia** conectando o que importa.

## Instalação

**Pré-requisitos:** macOS, Claude Code CLI, `jq` (`brew install jq`).

```
/plugin marketplace add ivancojr/startupz-claude-plugin
/plugin install startupz-claude-plugin
/startupz:setup
```

Pronto. Amanhã 7h o cron gera o briefing; ao abrir o Claude Code, ele aparece automático.

## Comandos

| Comando | O que faz |
|---|---|
| `/startupz:setup [hora] [min]` | Instala o cron diário. Default: 7h. |
| `/startupz:morning` | Exibe o briefing do dia (gera sob demanda se faltar). |
| `/startupz:uninstall` | Remove o cron. Mantém histórico. |

## Arquivos

- Briefings: `~/.startupz/briefings/YYYY-MM-DD.md`
- Logs: `~/.startupz/logs/YYYY-MM-DD.log`
- Plist do launchd: `~/Library/LaunchAgents/co.startupz.briefing.plist`

## Limitações do MVP

- macOS apenas (Linux/cron na v0.2).
- Fontes RSS hardcoded (config.json customizável: futuro).
- Sem personalização por categoria.

## Licença

MIT.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: write README with install steps, commands table, and limitations"
```

---

### Task 15: Smoke test end-to-end

**Files:**
- Create: `tests/smoke-e2e.sh`

- [ ] **Step 1: Criar smoke test**

```bash
#!/usr/bin/env bash
# smoke-e2e.sh — roda fluxo completo num HOME temporário.
# Não chama LLM real (--no-llm).

set -euo pipefail

TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"
PLUGIN_PATH=$(cd "$(dirname "$0")/.." && pwd)
export STARTUPZ_PLUGIN_PATH="$PLUGIN_PATH"

echo "=== HOME temp: $TMP_HOME ==="

# Stub launchctl
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
```

- [ ] **Step 2: Tornar executável e rodar**

```bash
chmod +x tests/smoke-e2e.sh
bash tests/smoke-e2e.sh
```
Expected: "TODOS OS PASSOS PASSARAM" no final.

- [ ] **Step 3: Rodar TODOS os bats juntos**

```bash
bats tests/*.bats
```
Expected: todos passing (ou skips de rede aceitáveis).

- [ ] **Step 4: Commit final**

```bash
git add tests/smoke-e2e.sh
git commit -m "test: add end-to-end smoke test covering install → generate → hook → uninstall"
```

---

## Self-Review (executado durante o write)

**1. Spec coverage:**
- ✅ Pipeline de geração → Task 9
- ✅ SessionStart hook → Task 10
- ✅ Slash commands setup/morning/uninstall → Tasks 11, 12, 13
- ✅ Skill startupz-briefing → Task 5
- ✅ Cron via launchd plist → Tasks 6, 7, 8
- ✅ Fontes RSS + Supabase → Tasks 3, 4
- ✅ Error handling (RSS off, Supabase off, claude falha) → coberto em generate-briefing.sh com fallback `--no-llm` (Task 9)
- ✅ Rotação 30 dias + backup regeneração → Task 9
- ✅ README de distribuição → Task 14
- ⚠️ Config `~/.startupz/config.json` — spec menciona como configurável; MVP hardcoda fontes em `generate-briefing.sh`. Out of scope explícito.

**2. Placeholder scan:** OK. Todas as tasks têm código real, comandos exatos, expected outputs.

**3. Type/naming consistency:**
- `STARTUPZ_PLUGIN_PATH` usado consistentemente em scripts e tests.
- `~/.startupz/briefings/`, `~/.startupz/logs/`, `~/.startupz/.shown-*` consistentes.
- Funções de lib: `parse_rss_file`, `fetch_rss_url`, `filter_within_hours`, `fetch_startupz_articles` — usadas exatamente assim em generate-briefing.sh e tests.
