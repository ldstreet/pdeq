# CLI Conventions

## Overview

Pdeq ships a set of slash commands that consumer projects invoke from inside Claude Code. Without a naming convention these commands collide with project-local slash commands and with commands installed by other tooling, and a maintainer browsing the slash-command palette has no way to tell at a glance which commands belong to pdeq. This spec records the convention that resolves both problems: every pdeq-installed slash command begins with the `pdeq-` prefix.

The prefix is a product decision, not a styling choice. It defines the contract a consumer can rely on — typing `/pdeq` and tab-completing surfaces the entire pdeq command surface, and any command that does not start with `pdeq-` is by definition not a pdeq command.

## User Stories

- As a **consumer-project maintainer**, I want every pdeq-installed slash command to start with the same prefix so that I can discover them all by typing `/pdeq` and tab-completing, and so that I can tell at a glance which slash commands in my palette came from pdeq versus my own project or other tooling.

## Requirements

### Slash Command Naming

Pdeq slash commands share a single discoverable prefix. The convention is enforced by the command files pdeq ships and propagated to consumers via the migration system.

- **Prefix on all commands** `FR-cli-naming-prefix`: All pdeq-installed slash commands begin with the `pdeq-` prefix.
- **Existing commands renamed** `FR-cli-naming-rename-existing`: Slash commands shipped by pdeq before this convention was adopted are renamed to carry the prefix. Consumer projects pick up the rename through the migration system the next time they upgrade.
- **Discoverable as a group** `FR-cli-naming-discoverable`: A consumer typing `/pdeq` in their slash-command palette can discover every pdeq-installed command at once, without needing to know any individual command's name in advance.
- **No collision with project-local commands** `FR-cli-naming-no-collision`: The `pdeq-` prefix prevents pdeq commands from colliding with bare-verb slash commands a consumer's own project or other tooling may ship.

## Acceptance Criteria

These cover the observable outcomes QA will test directly.

- [ ] **Listing groups under prefix** `AC-cli-naming-listing`: After installation, every pdeq-installed slash command in the consumer's palette begins with `pdeq-`, and typing `/pdeq` tab-completes the full set without surfacing any non-pdeq commands.
- [ ] **No bare-name pdeq command** `AC-cli-naming-no-bare-name`: After installation (and after any required migration has run), no pdeq-installed command exists at a bare-verb name (e.g. `/migrate`, `/kickoff`); the prefixed form is the only form available.
- [ ] **Migration carries the rename** `AC-cli-naming-migration-carries`: A consumer that bumps from a pre-prefix pdeq version to a post-prefix pdeq version and runs the upgrade flow ends up with the prefixed commands available in their palette without manual file edits, except in cases where the consumer had previously customized a command file (in which case the migration leaves the customization alone and surfaces a one-line warning).

## Open Questions

- **Custom-command guidance for consumers:** Should pdeq publish guidance recommending that consumers also prefix their own project-local slash commands (e.g. with a project tag) so the palette stays organized? Out of scope for this convention — pdeq controls only its own command surface.

## Dependencies

- **Migration system (`product/migrations.md`):** the rename of existing commands is delivered via the migration system. Without the migration system, existing consumers would not pick up the rename.
- **Glossary:** introduces the term *Pdeq command prefix* — see `../glossary.md`.
