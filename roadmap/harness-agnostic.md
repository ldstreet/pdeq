# Harness-Agnostic — Roadmap

Pdeq 0.4.0 made the framework installable into and operable from multiple coding-agent harnesses (Claude Code, Codex CLI, Pi). The v1 cut intentionally kept the harness adapter table small and the slash-command surface Claude-only. This roadmap parks forward-looking ideas for that work.

See current state in [../product/harness-agnostic.md](../product/harness-agnostic.md).

## Fast Follow

Ideas worth picking up if the rough edges from v1 prove painful in practice.

- **Native Pi extension for `/pdeq-*` commands** — Ship a Pi TypeScript extension that registers `/pdeq-kickoff`, `/pdeq-migrate`, `/pdeq-status`, etc. as real Pi slash commands by reading the existing `pdeq-rules/commands/<name>.md` prompt files and injecting them into the agent's next turn. Today (v0.4.0) Pi users invoke pdeq workflows via prose ("do a pdeq migration"); the canonical `AGENTS.md` has a section instructing the agent to read the prompt file in that case. That works but loses palette discoverability and tab-completion. A native extension would restore both. First step is a spike on Pi's extension API (registration, prompt-injection primitive, fs access, distribution mechanism — npm package vs. git clone into `~/.pi/agent/`) before committing to an implementation shape.

## V2

Larger directional bets.

- **Additional harnesses in the adapter table** — Cursor, Goose, Gemini, Copilot, AMP, Cline. Each has a documented `AGENTS.md` (or equivalent) convention per the `block/ai-rules` mapping table, so adding a row to the adapter table inside `scripts/init.sh` is a one-commit change per harness. Gated on actual user demand: pdeq has no evidence today that any of these matter to consumers. Add as users surface the need rather than speculatively.
- **MCP server configuration shipped per harness** — pdeq could provide a default MCP server config (e.g., for repo-aware grep/symbol lookup) that materializes into the right per-harness location (`.mcp.json` for Claude, `.cursor/mcp.json` for Cursor, etc.). Today pdeq ships no MCP. Worth revisiting if pdeq grows ambient capabilities that benefit from MCP exposure.
- **Cross-harness skill format** — Pi's "skills" and Claude Code's "skills" are differently shaped; pdeq's current `.claude/skills/pdeq/SKILL.md` is Claude-only and was deliberately excluded from the cross-harness contract in v1. If a non-Claude harness grows a skill-like primitive and pdeq wants to expose setup helpers in that surface too, design a neutral skill format and per-harness materialization.

## Later

Speculative — only worth thinking about once the above lands and we have user feedback.

- **Adopt `block/ai-rules` as the materialization engine** — Today pdeq's per-harness adapter table is ~60 lines of bash in `scripts/init.sh`, and the install-dependency floor stays at `git + bash`. If pdeq grows beyond the three v1 harnesses and the table starts repeating logic that `block/ai-rules` already implements (per-harness MCP overlays, frontmatter-driven rule splits, generated-file tracking via `ai-rules status`), it may be worth swapping in the Rust CLI. Trade-off is a new install dependency for consumers, so the bar to switch is "the adapter table is meaningfully more work to maintain in-house than the dependency tax is to ask of consumers." Not there at v1.
- **Harness-aware audit** — `scripts/audit-traceability.sh` currently treats all `.md` files uniformly. Future harnesses might introduce per-harness command directories (e.g., `.cursor/commands/`) that should also be excluded from slug scans. The audit's exclude list could read pdeq.json's `harnesses` and dynamically extend its skip set. Cheap to do; gated on a real harness having an exclusion need that the current `CLAUDE.md`/`AGENTS.md` filter doesn't already cover.
