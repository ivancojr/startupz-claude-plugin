# Startupz Claude Plugin

Briefing diário do ecossistema brasileiro de startups, direto no seu Claude Code.

Todo dia de manhã, você abre o Claude e o briefing já está lá: 3 destaques do **Startupz**, 5-8 manchetes do ecossistema BR (Brazil Journal, Startupi, Neofeed, Pipeline Valor, Startups.com.br), e um bloco de **insights do dia** conectando o que importa.

## Instalação

### Claude Code CLI / Desktop (macOS)

**Pré-requisitos:** Claude Code, `jq` (`brew install jq`).

```
/plugin marketplace add ivancojr/startupz-claude-plugin
/plugin install startupz-claude-plugin@startupz
/startupz:setup
```

Amanhã 7h o cron gera o briefing; ao abrir o Claude Code, ele aparece automático.

### Cowork / Claude Code Web

```
/plugin marketplace add ivancojr/startupz-claude-plugin
/plugin install startupz-claude-plugin@startupz
/startupz:morning
```

Cowork não tem cron local, então `/startupz:morning` faz fetch das fontes em paralelo e gera o briefing inline (~30-60s).

## Comandos

| Comando | O que faz | Onde funciona |
|---|---|---|
| `/startupz:setup [hora] [min]` | Instala o cron diário (default 7h). | Claude Code CLI (macOS) |
| `/startupz:morning` | Exibe o briefing do dia. Usa o local salvo se houver, senão gera inline via WebFetch. | CLI, Cowork, Chat web |
| `/startupz:uninstall` | Remove o cron. Mantém histórico. | Claude Code CLI (macOS) |

## Onde funciona

- **Claude Code CLI (macOS):** experiência completa — cron local 7h + briefing aparece automático ao abrir.
- **Cowork (`claude.ai/code` web):** sem cron, mas `/startupz:morning` faz fetch e gera inline quando você pede.
- **Chat web (`claude.ai`):** mesmo `/startupz:morning` — fetch + síntese inline.

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
