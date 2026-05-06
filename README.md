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
