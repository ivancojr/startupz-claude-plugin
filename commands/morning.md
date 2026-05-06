---
description: Exibe o briefing Startupz do dia. Funciona em CLI, Cowork e Chat — gera inline se necessário.
---

# /startupz:morning

Apresenta o briefing diário do ecossistema brasileiro de startups. A estratégia depende do surface:

1. **Claude Code CLI com cron instalado**: existe um briefing salvo em `~/.startupz/briefings/YYYY-MM-DD.md` (gerado pelo launchd). Use ele.
2. **Cowork, Chat web, ou CLI sem cron**: gera inline agora via WebFetch das fontes.

## Passo 1 — Tentar briefing local

Use a tool `Read` (se disponível) ou `Bash` (se disponível) pra checar se existe `~/.startupz/briefings/{data de hoje no formato YYYY-MM-DD}.md`.

- **Se existe**: leia e exiba o conteúdo no chat. Pare aqui.
- **Se não existe ou Read/Bash não estão disponíveis**: prossiga pro Passo 2.

## Passo 2 — Geração inline

Faça fetch destas fontes em paralelo (use `WebFetch` ou `web_fetch`, uma chamada por URL):

**Fontes RSS:**
- `https://braziljournal.com/feed/`
- `https://startupi.com.br/feed/`
- `https://www.neofeed.com.br/feed`
- `https://valor.globo.com/pipeline/rss`
- `https://startups.com.br/feed/`

**Startupz (Supabase REST):**
- URL: `https://vfntyqijlrdlgcponeez.supabase.co/rest/v1/articles?select=title,slug,excerpt,category,published_at,author_name&published=eq.true&order=published_at.desc&limit=10`
- Header: `apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmbnR5cWlqbHJkbGdjcG9uZWV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNTg3NDUsImV4cCI6MjA4MDgzNDc0NX0.zyyjWLAz1yGMBIWllFHl7RfGtDDkg9y5sI_bVpnkj5o`

Pra cada fonte:
- Filtre itens publicados nas últimas 24h pelo campo `pubDate` (RSS) ou `published_at` (Supabase).
- Se a fonte falhar, ignore silenciosamente e siga.

## Passo 3 — Sintetizar

Use a skill `startupz-briefing` (carregada por este plugin) pra gerar o briefing seguindo a estrutura obrigatória:

```markdown
# Briefing Startupz — {data}

## Destaques do Startupz
[3-5 artigos do Supabase. Para cada: título como subheader, 1 parágrafo com excerpt + contexto, link.]

## O que rolou no ecossistema BR
[5-8 manchetes das fontes RSS. Cada uma: 1-2 frases + fonte (link).]

## Insights do dia
[~400 palavras. Análise conectando 2-3 itens. Tendência observada. "O que isso significa pra empreendedores BR" — pragmático, acionável.]
```

**Tom:** founder-to-founder, português brasileiro neutro. Sem clichês de newsletter ("imperdível", "fique por dentro"). Sem self-references (Claude/IA/modelo). Toda manchete tem link.

Se um bloco fica vazio (ex: Supabase sem publicação), insira nota curta — não esconda a seção.

## Passo 4 (CLI apenas, opcional)

Se você está no Claude Code CLI e teve que gerar inline (Passo 2 caiu pq cron não rodou), salve o resultado em `~/.startupz/briefings/{data}.md` pra reuso no resto do dia.
