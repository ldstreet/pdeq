# Decision Log

This is an append-only log of key architectural, product, and design decisions and their rationale. It provides historical context for how the project evolved — specs show the current state, this log shows *why*.

**Agent rule:** Do NOT write directly to this file during a session. Instead, write new entries to `decisions-pending.md` using the format below. The `scripts/merge-decisions.sh` pre-commit hook merges all pending entries into this file at commit time, then deletes `decisions-pending.md`. This keeps diffs clean and avoids churn on a shared file during multi-step sessions.

## Entry Format

```
## YYYY-MM-DD — [Decision Title]
**Decision**: [What was decided]
**Rationale**: [Why]
**Alternatives considered**: [What else was evaluated]
```

---

<!-- Decision entries appear below, oldest first. -->
