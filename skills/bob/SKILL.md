---
name: bob
description: |
  Cross-project scheduler and priority manager. Reads all active bob.md project files,
  builds priority views by deadline pressure, and runs daily/weekly/monthly planning conversations.
  Use for daily briefings, weekly planning, project status updates, and project launch.
  Trigger: /bob, /bob daily, /bob weekly, /bob monthly, /bob quarterly,
           /bob [project-name], /bob add, /bob update [project-name], /bob scan,
           /bob ideas
author: Claude Code Academic Workflow
version: 1.0.0
argument-hint: "[daily|weekly|monthly|quarterly|grants|add|scan|update <project>|<project-name>]"
---

# /bob — Meta Project Scheduler

Survey all active projects, surface deadline pressure, and help plan what to work on.

## How It Works

The bob agent reads two registry files to discover all projects:
- `~/.claude/bob/registry.md` — cloud-synced projects (portable across machines)
- `~/.claude/bob/registry-local.md` — machine-local GitHub projects

It then reads each project's `bob.md` file and builds the requested view.

## Argument Parsing

Parse `$ARGUMENTS` and pass the appropriate mode to the bob agent:

| Arguments | Mode | What happens |
|-----------|------|--------------|
| (none) or `daily` | daily | Today's priority briefing |
| `weekly` | weekly | This week's planning conference |
| `monthly` or `quarterly` | monthly | Long-horizon milestone review |
| `add` | add | Register a new project interactively |
| `scan` | scan | Check all projects for staleness |
| `grants` | grants | Full grant portfolio view organized by phase |
| `update [project-name]` | update | Trigger status update for a project |
| `ideas` | ideas | Browse or add to the future projects backlog |
| `remind [note] on [date]` | remind | Write a note + create macOS Reminder |
| `event [title] on [date]` | event | Create iCal event + update calendar |
| anything else | project lookup | Treat as project name, surface details + path |

---

## Dispatch

Dispatch the `bob` agent with the following context:

```
Mode: [parsed mode from argument table above]
Arguments: $ARGUMENTS
Today's date: [today's date]

Registry files:
- Synced: ~/.claude/bob/registry.md
- Local: ~/.claude/bob/registry-local.md

Templates location (for /bob add):
~/.claude/skills/bob/templates/

Run the appropriate mode as described in the bob agent instructions.
```

---

## First-Run Behavior

If both registry files are empty (no projects listed), bob should skip the view and say:

> "The registry is empty — I have no projects to survey. Run `/bob add` to register your first project, and I'll start keeping tabs on it."

---

## Notes

- bob.md files live at `[project_root]/bob.md`
- The registry is the source of truth for which projects exist; bob.md is the source of truth for their status
- Daily mode is the default when called with no arguments — quick, not a ceremony
- Daily/weekly/monthly views include an importance-based "don't let this slide" check — high-importance, not-urgent projects get surfaced on purpose so they don't lose out to whatever's merely loud (see the Eisenhower Check in `agents/bob.md`)
- See `rules/bob-md-vs-claude-md.md` for what belongs in bob.md vs. a project's own CLAUDE.md
