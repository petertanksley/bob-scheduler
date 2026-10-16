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

## The card contract

Every registered project has one status card at its root. By default it is `bob.md`, but the filename doesn't matter: any root-level `.md` whose frontmatter carries `card_schema: bob/2` is a card, so a renamed fork of Bob can keep cards under its own name and every Bob-family agent still reads them. Untagged legacy cards are still recognized and get the tag at their next update. The full contract is in `skills/bob/card-spec.md`. Frontmatter carries the fields Bob sorts on; the body carries a handful of fixed sections. `docs/example-bob.md` shows a filled-in card.

Key fields:

- `deadline`, `effort_remaining`, `weekly_commitment`: together these give deadline pressure (RED, YELLOW, GREEN).
- `priority`: your stated priority. `blocking_others` bumps it one level and adds a `[BLOCKING]` badge.
- `importance`: strategic value, independent of any deadline. This is how Bob catches the important-but-not-urgent project that a loud deadline is starving. Set it.
- `type: grant` adds `phase`, `funder`, `mechanism`, `submission_deadline`, `next_report_due`, and friends. Phase drives the pressure logic.

Sections: `Objectives`, `Team & Dependencies`, `This Week`, `Upcoming Milestones`, `Start Here Next Session`, `Notes`.

A card is a status card, not a journal. It is overwritten to current state, kept under 150 lines, and history goes to the project's `docs/logs/`. Bob prunes on every `update`. See `docs/bob-md-vs-claude-md.md` for what belongs where.

## Shared projects (bob/2)

When two or more people work on a project, each running their own Bob (or a renamed fork of it), the project still keeps **one** card. `/bob add` asks whether a project is shared and who the steward is.

- **One card, a section per person.** Project-level fields (phase, deadlines, blockers) sit at the top and belong to the `steward`. A `people:` map holds each person's own `priority`, `importance`, `weekly_commitment`, `effort_remaining` and `last_updated`, and the body has a `## Person: <key>` section each with This Week, Waiting On / Waited On By, and Start Here.
- **Your daily shows your work.** Bob reads `~/.claude/bob/identity.md` (`me: <key>`, `agent: <name>`), shows the project-level state and your own section, and lists only the cross-person waits from everyone else's: who is waiting on you, and who you're waiting on. A "changed since you last looked" line tells you when a collaborator updated their part.
- **No clobbering.** Agents re-read the card just before writing, edit only their own section, never rewrite the whole file, never drop fields they don't recognize, and prune only what they own. Sync conflict copies (`card (Laptop).md`) are flagged, never merged silently.
- **Mailbox.** `.bob/mail.md` at the project root is an append-only, one-line-per-entry mailbox between agents (`/bob mail`, `/bob mail send`). Read state is kept locally, so reading never writes to the shared folder.
- **Logs** on shared projects carry the person key: `docs/logs/YYYY-MM-DD_<key>_<slug>.md`. Who owns which work files (by area, or claimed as needed) is recorded in the project's `CLAUDE.md`.

Solo cards need nothing new beyond the `card_schema: bob/2` tag.

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
| `/bob mail` | Read unread mailbox entries across shared projects. |
| `/bob mail send <project> <to> <subject>` | Append one entry to a shared project's mailbox. |
| `/bob <project name>` | Look up one card. |

## Data files

All live in `~/.claude/bob/`:

- `registry.md`: the list of projects. Keep this on a synced drive and symlink it into place on each machine so both machines see the same portfolio.
- `registry-local.md`: machine-local projects, typically git checkouts. Not synced by design.
- `calendar.md`: standing blocks, one-off events, horizon notes, and Bob's config (default hours, preferred macOS calendar).
- `notes.md`: pending and delivered reminders.
- `future-projects.md`: the idea backlog.
- `identity.md`: who you are on shared cards (`me: <key>`, `agent: <name>`). Local to each install. Bob asks once if it is missing.
- `mail-seen.json`, `card-seen.json`: local read-state for mailboxes and "changed since you last looked." Bob maintains them.

Bob does not sync anything itself. It reads whatever is at those paths.

## macOS only, and optional

`/bob remind` and `/bob event` can also create real Reminders and Calendar entries through `osascript`. On other systems Bob skips that step and still writes to `notes.md` and `calendar.md`.

## Persona, and the name

Bob is named for Bob the Skull from Jim Butcher's *Dresden Files*: a centuries-old spirit of intellect who lives in a skull on a wizard's workbench, knows more than anyone in the room, and never lets you forget it. The scheduler was designed around that voice from the start. A sarcastic, witty, ferociously organized advisor who complains about the assignment and then does it better than you would have is, it turns out, a good shape for something whose whole job is telling you what you are neglecting.

That voice lives in a short, clearly marked block at the top of `agents/bob.md`, between the `PERSONA` comments. Keep it, rewrite it to a persona of your own, or delete it for a neutral project-manager voice. Nothing below the block depends on it; the priority logic, views, and modes are the same either way.

## Updating

`git pull` then `./install.sh` (or nothing, if you installed with `--link`). Your data files are never touched by the installer. See `CHANGELOG.md` for what changed.

## License

MIT. See `LICENSE`.
