# Startupz Claude Plugin — Design

**Data:** 2026-05-06
**Autor:** Ivan (mentorboxx@gmail.com)
**Status:** Aprovado, aguardando plano de implementação

## Objetivo

Plugin Claude Code que entrega ao usuário, todo dia de manhã, um briefing curado do ecossistema brasileiro de startups. O Startupz funciona como âncora de conteúdo, complementado por agregação de fontes externas BR. O briefing é gerado por cron local (macOS launchd) às 7h e exibido automaticamente na primeira sessão do dia ao abrir o Claude Code.

A experiência alvo: pessoa instala o plugin, roda `/startupz:setup` uma vez, e a partir do dia seguinte abre o Claude Code de manhã e o briefing já está lá no chat — sem precisar pedir.

## Público & posicionamento

Empreendedores brasileiros que usam Claude Code como espaço de trabalho. O plugin é o "primeiro café com o ecossistema": curadoria do que importa, escrita em tom founder-to-founder, com insights conectando os pontos. Não é newsletter, não é agregador de RSS — é um briefing executivo gerado por IA com a curadoria editorial do Startupz como espinha.

## Arquitetura

```
                ┌─────────────────────────┐
                │  launchd (macOS)        │  7h diário
                │  → claude --print …     │
                └────────────┬────────────┘
                             │
                             ▼
              ┌──────────────────────────────┐
              │ scripts/generate-briefing.sh │
              │  1. fetch RSS (5 fontes)     │
              │  2. fetch Startupz Supabase  │
              │  3. monta prompt + skill     │
              │  4. salva markdown           │
              └────────────┬─────────────────┘
                           │
                           ▼
            ~/.startupz/briefings/YYYY-MM-DD.md
                           ▲
                           │ lê e injeta
                ┌──────────┴──────────────────┐
                │ hooks/session-start.sh      │
                │ (carrega como contexto)     │
                └─────────────────────────────┘
```

Slash commands paralelos: `/startupz:setup` (instala cron), `/startupz:morning` (re-exibe ou força geração), `/startupz:uninstall` (remove cron, mantém histórico).

## Estrutura do plugin

```
startupz-claude-plugin/
├── plugin.json
├── README.md
├── commands/
│   ├── setup.md
│   ├── morning.md
│   └── uninstall.md
├── hooks/
│   └── session-start.sh
├── skills/
│   └── startupz-briefing/
│       └── SKILL.md
├── scripts/
│   ├── generate-briefing.sh    # entrypoint do cron
│   ├── lib/
│   │   ├── fetch-rss.sh        # função: parse RSS de uma URL
│   │   └── fetch-startupz.sh   # função: query Supabase
│   ├── install-cron.sh
│   └── uninstall-cron.sh
├── templates/
│   └── co.startupz.briefing.plist.tmpl
└── tests/
    ├── test-rss-fetch.sh
    ├── test-supabase.sh
    ├── test-briefing-format.sh
    └── test-cron-install.sh
```

## Fontes de conteúdo

| Fonte | Tipo | Endpoint |
|-------|------|----------|
| Startupz | Supabase REST | `https://vfntyqijlrdlgcponeez.supabase.co/rest/v1/articles` |
| Brazil Journal | RSS | `https://braziljournal.com/feed/` |
| Startupi | RSS | `https://startupi.com.br/feed/` |
| Neofeed | RSS | `https://www.neofeed.com.br/feed` |
| Pipeline Valor | RSS | `https://valor.globo.com/pipeline/rss` |
| Startups.com.br | RSS | `https://startups.com.br/feed/` |

URLs de RSS são tratadas como configuráveis em `~/.startupz/config.json` — usuário pode adicionar/remover fontes pós-instalação. Endpoint do Supabase Startupz é fixo (é a "âncora" do plugin).

Filtro temporal: itens com `pubDate` nas últimas 24h. Janela ajustável via config.

## Pipeline de geração (`scripts/generate-briefing.sh`)

1. **Fetch fontes externas** — chamadas `curl` paralelas com timeout 10s por fonte. Falha de fonte individual é silenciosa (loga, segue). Parser RSS via `xmllint` ou `xq` (jq pra XML).

2. **Fetch Startupz** — Supabase REST com anon key embedada (chave pública, OK):
   ```
   GET /rest/v1/articles
       ?select=title,slug,excerpt,category,published_at,author_name
       &published=eq.true
       &published_at=gte.{ontem 7h ISO}
       &order=published_at.desc
       &limit=10
   ```

3. **Monta prompt** — JSON estruturado com todos os itens coletados, separados por fonte. Inclui categoria/data/autor quando disponível.

4. **Chama Claude headless** — `claude --print --skill startupz-briefing`. A skill `startupz-briefing` está instalada localmente pelo plugin e fornece tom + estrutura + restrições.

5. **Salva** — `~/.startupz/briefings/YYYY-MM-DD.md`. Se já existe (regeneração via `/startupz:morning`), faz backup como `YYYY-MM-DD.md.bak` antes de sobrescrever, e o novo arquivo recebe um marcador `<!-- regenerated at HH:MM -->` no topo.

6. **Rotação** — mantém 30 dias, deleta arquivos mais antigos.

7. **Log** — `~/.startupz/logs/YYYY-MM-DD.log` com timestamps de cada etapa, fontes que falharam, tamanho do briefing final.

## Formato do briefing

```markdown
# Briefing Startupz — {data}

## Destaques do Startupz
[3-5 artigos publicados nas últimas 24h, com excerpt original e link]

## O que rolou no ecossistema BR
[5-8 manchetes agregadas, 1-2 frases cada, com fonte e link]

## Insights do dia
[Análise conectando 2-3 itens. Tendência observada. "O que isso significa pra empreendedores BR." ~400 palavras.]
```

Tamanho total: ~1500 palavras. Sempre tem os 3 blocos. Se um bloco fica vazio (ex: Startupz sem publicação no dia), insere nota curta — não esconde a seção.

## SessionStart hook

```bash
#!/usr/bin/env bash
set -e
TODAY=$(date +%Y-%m-%d)
BRIEFING="$HOME/.startupz/briefings/$TODAY.md"
FLAG="$HOME/.startupz/.shown-$TODAY"

[ -f "$FLAG" ] && exit 0
[ ! -f "$BRIEFING" ] && exit 0

cat "$BRIEFING"
touch "$FLAG"
```

Comportamento:
- Mostra briefing apenas na primeira sessão do dia (flag `.shown-YYYY-MM-DD`).
- Silencioso se briefing do dia ainda não foi gerado.
- Não prefixa com headers próprios — o markdown do briefing já tem `# Briefing Startupz — {data}`.

## Slash commands

### `/startupz:setup`
Pergunta ao usuário:
1. Horário do briefing (default 07:00)
2. Fuso horário (default `America/Sao_Paulo`)

Ações:
- Cria `~/.startupz/` com `config.json` (horário, fuso, fontes ativas).
- Renderiza `templates/co.startupz.briefing.plist.tmpl` com horário/fuso → `~/Library/LaunchAgents/co.startupz.briefing.plist`.
- `launchctl load -w ~/Library/LaunchAgents/co.startupz.briefing.plist`.
- Roda `scripts/generate-briefing.sh` uma vez imediatamente pra ter briefing já no dia 1.
- Exibe próximo passo: "Pronto. O briefing de amanhã 7h aparece automático ao abrir Claude."

### `/startupz:morning`
- Se `~/.startupz/briefings/$(date +%F).md` existe → exibe.
- Senão → roda `generate-briefing.sh` síncrono (com spinner) e exibe.
- Útil quando máquina dormiu durante o cron, ou pessoa quer regenerar.

### `/startupz:uninstall`
- `launchctl unload ~/Library/LaunchAgents/co.startupz.briefing.plist`.
- Remove plist.
- **Mantém** `~/.startupz/briefings/` e `logs/` (histórico do usuário).
- Avisa que pra remover histórico é manual: `rm -rf ~/.startupz`.

## Skill interna `startupz-briefing`

`SKILL.md` frontmatter:
```yaml
---
name: startupz-briefing
description: Gera briefing diário do ecossistema brasileiro de startups com tom Startupz. Use quando o pipeline de geração chamar.
---
```

Conteúdo:
- **Tom:** direto, founder-to-founder, português brasileiro neutro. Sem clichês de newsletter ("imperdível", "você não pode perder", "fique por dentro"). Sem emojis no corpo (apenas no header se necessário).
- **Estrutura obrigatória:** 3 blocos (`## Destaques do Startupz`, `## O que rolou no ecossistema BR`, `## Insights do dia`).
- **Insights:** análise conectando 2-3 itens do dia. Identifica tendência. Termina com "o que isso significa pra empreendedores BR" — pragmático, acionável.
- **Tamanho:** ~1500 palavras totais.
- **Restrições:** Sem self-references (Claude/IA/modelo/Anthropic). Sem inventar dados — se item da fonte não tem detalhe, não fabrica.
- **Citações:** Toda manchete tem link da fonte. Toda análise referencia itens específicos.

## Configuração (`~/.startupz/config.json`)

```json
{
  "schedule": {
    "hour": 7,
    "minute": 0,
    "timezone": "America/Sao_Paulo"
  },
  "sources": {
    "startupz": { "enabled": true },
    "rss": [
      { "name": "Brazil Journal", "url": "https://braziljournal.com/feed/", "enabled": true },
      { "name": "Startupi", "url": "https://startupi.com.br/feed/", "enabled": true },
      { "name": "Neofeed", "url": "https://www.neofeed.com.br/feed", "enabled": true },
      { "name": "Pipeline Valor", "url": "https://valor.globo.com/pipeline/rss", "enabled": true },
      { "name": "Startups.com.br", "url": "https://startups.com.br/feed/", "enabled": true }
    ]
  },
  "briefing": {
    "window_hours": 24,
    "max_words": 1500,
    "retention_days": 30
  }
}
```

## Error handling

| Cenário | Comportamento |
|---------|---------------|
| RSS de fonte individual fora do ar | Ignora a fonte, loga `WARN`, segue. |
| Supabase Startupz fora | Bloco "Destaques" vira nota curta, segue com agregadas + insights. |
| Nenhuma fonte respondeu | Briefing fallback: "Não foi possível buscar conteúdo hoje." Loga `ERROR`. |
| Janela 24h sem nada novo | Gera briefing com nota "ecossistema quieto hoje" + insights de tendência baseados em janela 7d. |
| `claude --print` falha | Salva briefing fallback raw (lista plana das manchetes sem insights). Loga `ERROR`. |
| Cron não disparou (máquina dormiu) | Hook fica silencioso. `/startupz:morning` resolve sob demanda. |
| Disco cheio | Geração falha, log escreve em stderr do launchd. |

## Testes

- `test-rss-fetch.sh` — mock de feed XML local, valida parsing de title/link/pubDate/description.
- `test-supabase.sh` — hit real no endpoint público (read-only), valida estrutura JSON e schema esperado.
- `test-briefing-format.sh` — gera briefing num ambiente de teste, faz `grep` dos 3 headers obrigatórios e checa contagem aproximada de palavras.
- `test-cron-install.sh` — instala plist em diretório temporário, valida XML válido, valida `launchctl print` lista o job.
- Smoke manual: `bash scripts/generate-briefing.sh --dry-run` imprime o que faria sem salvar.

## Distribuição

- Repo público: `ivancojr/startupz-claude-plugin` (separado do `startupz-brutal`).
- Instalação no Claude Code:
  ```
  /plugin marketplace add ivancojr/startupz-claude-plugin
  /plugin install startupz-claude-plugin
  /startupz:setup
  ```
- README com 3 passos + screenshot do briefing renderizado.
- Versionamento: SemVer, `plugin.json` declara versão.

## Out of scope (MVP)

- Personalização por categoria/tema de interesse.
- Multi-canal de delivery (e-mail, WhatsApp, Telegram).
- Linux (cron) e Windows (Task Scheduler) — MVP é macOS via launchd. Linux fica pra v0.2.
- Busca/histórico de briefings antigos como recurso da skill.
- Métricas de uso/analytics.
- Editor de fontes via slash command (no MVP, edita `config.json` manualmente).
- Integração com o backend do `startupz-brutal` (Supabase) além de leitura pública de `articles`.

## Premissas & dependências

- macOS com `launchd`, `bash`, `curl`, `xmllint` (vêm por default). `jq` é dependência adicional — `/startupz:setup` checa se está no PATH e, se faltar, exibe instrução `brew install jq` e aborta com mensagem clara. Plugin **não** instala `brew` ou `jq` automaticamente.
- Claude Code CLI no PATH (necessário pro cron rodar `claude --print`).
- Supabase do Startupz mantém endpoint público de `articles` com schema atual (`title`, `slug`, `excerpt`, `published`, `published_at`, `category`, `author_name`).
- Nenhuma das 5 fontes externas exige autenticação ou rate-limiting agressivo na janela diária.

## Riscos

| Risco | Mitigação |
|-------|-----------|
| Mudança no schema do Supabase Startupz | Plugin lê só campos estáveis (title/slug/excerpt). Falha graciosa se faltar campo. |
| RSS de fonte muda formato | Parser tolerante (try/catch por item, ignora itens malformados). |
| `claude --print` mais caro do que o esperado em volume | MVP roda 1×/dia por usuário. Custo previsível. |
| Pessoa não vê o briefing porque máquina estava desligada às 7h | `/startupz:morning` cobre. SessionStart hook é só "best effort". |
| Briefing ficar genérico/sem voz Startupz | Skill com restrições explícitas + exemplos de "bom" vs "ruim" no SKILL.md. |
