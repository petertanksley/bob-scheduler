# Bob — a cross-project scheduler for Claude Code

Bob is a `/bob` skill plus an agent that keeps a portfolio of research projects in view. Each project carries a small status card called `bob.md`. Bob reads every card, crosses deadline pressure with your calendar and with how much each project actually matters, and runs short daily, weekly, and monthly planning conversations. It never does research, writes code, or drafts papers. It tells you where things stand and lets you decide.

Built for an academic workload: grants with phases, papers with venues, data resources, courses, admin, and the one exploratory project that always gets crowded out.

## What you get

| Piece | Path | Role |
|-------|------|------|
| Skill | `skills/bob/SKILL.md` | The `/bob` command. Parses the mode and dispatches the agent. |
| Agent | `agents/bob.md` | All the logic: priority formula, views, modes, the bob.md contract. |
| Templates | `skills/bob/templates/*.md` | Starter `bob.md` for six project types: research, grant, writing, admin, web, exploratory. |
| Hooks | `hooks/*.py` | Friday nudge to run `/bob weekly`; deliver due notes at session start; remind to update the card at session end. |
| Starter data | `bob-starter/*.md` | Blank registry, calendar, notes, and idea backlog. Installed to `~/.claude/bob/` once, never overwritten. |
| Docs | `docs/` | A worked example card and the rule that separates `bob.md` from `CLAUDE.md`. |

## Install

```bash
git clone https://github.com/petertanksley/bob-scheduler.git
cd bob-scheduler
./install.sh            # copies into ~/.claude; re-run to update
# or: ./install.sh --link   symlinks back to this checkout so `git pull` updates in place
```

Then two manual steps:

1. **Hooks.** Merge `settings.hooks.example.json` into `~/.claude/settings.json` (or `settings.local.json`). Hooks are optional. Without them Bob still works; you just lose the Friday nudge and the note delivery.
2. **Permissions.** Bob reads `bob.md` files across every project you register, so add the parent directories of your projects and `~/.claude/bob` to `permissions.additionalDirectories` in `~/.claude/settings.json`. Otherwise every read prompts.

Start a new session and run `/bob add` to register your first project.

## The bob.md contract

Every registered project has a `bob.md` at its root. Frontmatter carries the fields Bob sorts on; the body carries a handful of fixed sections. `docs/example-bob.md` shows a filled-in card.

Key fields:

- `deadline`, `effort_remaining`, `weekly_commitment`: together these give deadline pressure (RED, YELLOW, GREEN).
- `priority`: your stated priority. `blocking_others` bumps it one level and adds a `[BLOCKING]` badge.
- `importance`: strategic value, independent of any deadline. This is how Bob catches the important-but-not-urgent project that a loud deadline is starving. Set it.
- `type: grant` adds `phase`, `funder`, `mechanism`, `submission_deadline`, `next_report_due`, and friends. Phase drives the pressure logic.

Sections: `Objectives`, `Team & Dependencies`, `This Week`, `Upcoming Milestones`, `Start Here Next Session`, `Notes`.

A card is a status card, not a journal. It is overwritten to current state, kept under 150 lines, and history goes to the project's `docs/logs/`. Bob prunes on every `update`. See `docs/bob-md-vs-claude-md.md` for what belongs where.

## Modes

| Command | What happens |
|---------|--------------|
| `/bob` or `/bob daily` | Today's briefing: available hours, urgent items, three or four focus tasks, the important-not-urgent check, blockers. |
| `/bob weekly` | Planning conference: availability, project table, quadrant check, recommendations, forward-look questions. |
| `/bob monthly` or `quarterly` | Milestone map, stale-project sweep, horizon notes. |
| `/bob grants` | Grant portfolio by phase. |
| `/bob add` | Register a project; writes a `bob.md` from the matching template after a short interview. |
| `/bob update <project>` | Refresh a card, then prune it. |
| `/bob scan` | Flag stale cards, oversized cards, and cards missing `importance`. |
| `/bob ideas` | Browse or add to the idea backlog; launch one into a project. |
| `/bob remind <note> on <date>` | Note to your future self, delivered at session start when due. |
| `/bob event <title> on <date>` | Calendar entry that blocks planning time. |
| `/bob <project name>` | Look up one card. |

## Data files

All live in `~/.claude/bob/`:

- `registry.md`: the list of projects. Keep this on a synced drive and symlink it into place on each machine so both machines see the same portfolio.
- `registry-local.md`: machine-local projects, typically git checkouts. Not synced by design.
- `calendar.md`: standing blocks, one-off events, horizon notes, and Bob's config (default hours, preferred macOS calendar).
- `notes.md`: pending and delivered reminders.
- `future-projects.md`: the idea backlog.

Bob does not sync anything itself. It reads whatever is at those paths.

## macOS only, and optional

`/bob remind` and `/bob event` can also create real Reminders and Calendar entries through `osascript`. On other systems Bob skips that step and still writes to `notes.md` and `calendar.md`.

## Persona

The agent opens with a short, clearly marked persona block: Bob, a smug spirit of intellect who resents being demoted to project management. Delete the block between the `PERSONA` comments in `agents/bob.md` for a neutral voice, or rewrite it. Nothing below it depends on it.

## Updating

`git pull` then `./install.sh` (or nothing, if you installed with `--link`). Your data files are never touched by the installer.

## License

MIT. See `LICENSE`.
