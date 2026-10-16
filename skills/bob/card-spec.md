# Status card spec: `card_schema: bob/2`

A status card answers one question in the present tense: *where does this project stand right now, and how much of each person's time does it need?* This file is the contract that every agent reading or writing cards follows, including Bob and any descendant agents (forks of Bob renamed after their owners). Hooks and agents depend on the exact names below.

## 1. Finding the card

A project has **one** card, at its root.

1. **Explicit:** the registry entry may name the file, e.g. `[card: notes-card.md]`.
2. **Tagged:** any root-level `.md` (not `README.md`, `CLAUDE.md`, `MEMORY.md`) whose YAML frontmatter contains `card_schema: bob/2`.
3. **Legacy fallback:** a root-level `.md` whose frontmatter has `project:` and `last_updated:` plus `phase:` or `status:`. Treat it as bob/2 and add the tag at the next update.

`bob.md` is the default filename for new cards. A descendant agent may name its cards after itself. The filename never matters; the tag does.

**Conflict copies.** Sync tools create files such as `card (Some Laptop).md`, `card-MacBook-Pro.md` or `card 2.md` when two machines save at once. Agents flag these and never merge or delete them without the user.

## 2. Solo cards

A solo card is today's flat format plus the tag:

```yaml
---
card_schema: bob/2
project: ...
type: research
status: active
priority: medium
importance: high
deadline: 2027-01-15
effort_remaining: 20h
weekly_commitment: 4h
last_updated: 2026-10-16
...
---
```

Optional: `maintained_by: <key>` names the person who keeps a solo card. The session-start detect hook reports it, so an agent opening an unfamiliar folder knows whose card it is reading.

Body sections: Objectives, Team & Dependencies, This Week, Upcoming Milestones, Start Here Next Session, Notes. Budget: ≤ 150 lines; Notes ≤ 20; Start Here ≤ 10.

## 3. Shared cards

Used when more than one person works on a project. **One card per project, never one per person.**

```yaml
---
card_schema: bob/2
project: ...
type: grant
phase: active
shared: true
steward: ana               # owns project-level fields; prunes the project block
deadline: 2027-06-30
blockers: null
last_updated: 2026-10-16   # project-level fields only
people:
  ana:
    role: PI
    priority: high
    importance: high
    weekly_commitment: 11h
    effort_remaining: ~400h
    last_updated: 2026-10-15
  ben:
    role: Co-I
    priority: medium
    importance: high
    weekly_commitment: 5h
    effort_remaining: ~200h
    last_updated: 2026-10-16
---

## Project
### Objectives / Team & Dependencies / Upcoming Milestones / Notes

## Person: ana
### This Week
### Waiting On / Waited On By
### Start Here Next Session

## Person: ben
### This Week
### Waiting On / Waited On By
### Start Here Next Session
```

- `priority`, `importance`, `weekly_commitment` and `effort_remaining` are **per person**. The same project can be urgent for one person and background for another.
- Budget: project block (frontmatter plus `## Project`) ≤ 150 lines; each person section ≤ 60 lines.

## 4. Identity

Each install has `~/.claude/bob/identity.md`:

```
me: ben
agent: bob
```

- `me`: the person key. It tells the agent which `people:` entry and `## Person:` section are "mine."
- `agent`: this install's agent name. Defaults to `bob` when absent; a descendant agent sets its own name.

The file is local to the install and never stored in a project. If it is missing, the agent asks once and writes it.

## 5. Reading rules

A view built for `me` includes:

- the project-level fields,
- `people.<me>` (used for pressure, priority and importance),
- the `## Person: <me>` section,
- **cross-person waits**: lines in anyone's `Waiting On / Waited On By` that involve `me`,
- a **changed since you last looked** line, from local fingerprints (`~/.claude/bob/card-seen.json`) of the project block and each other person's section.

Other people's tasks never appear as the user's work.

## 6. Writing rules

1. Re-read the card immediately before every write.
2. Make targeted edits to your own `people.<me>` entry and `## Person: <me>` section. Never rewrite the whole file.
3. Project-level fields belong to the steward. A non-steward change needs a one-line log entry and a mailbox note to the steward.
4. **Never drop unknown fields, sections or comments.** A newer version or a descendant agent may have added them.
5. Prune only what you own (your section; the steward also prunes the project block).
6. Requests to other people go in your own `Waiting On / Waited On By`, never in their section.
7. Bump `people.<me>.last_updated` when you change your own section. Bump the project-level `last_updated` only when a project-level field changes.

## 7. History and conventions

- History lives in `docs/logs/`. On shared projects, put the person key in log names: `docs/logs/YYYY-MM-DD_<key>_<slug>.md`, and prune logs as `YYYY-MM-DD_<key>_bob-prune.md`.
- Working conventions (including who owns which work files, by area or by claim) live in the project's `CLAUDE.md`, not in the card.

## 8. Mailbox

`.bob/mail.md` at the shared project's root. It syncs wherever the project syncs.

```
# Mailbox — append-only; one line per entry
- 2026-10-16 | from: bob | to: all | Card format bob/2 | Shared cards now carry per-person sections; see card-spec.md.
```

- Append one line per entry. Never edit or reorder existing entries.
- `to:` is a comma list of person keys or agent names, or `all`. An entry is "mine" if `to:` contains my `me` key, my `agent` name, or `all`.
- Read state is local: `~/.claude/bob/mail-seen.json` maps the mailbox's absolute path to the sha1 hashes of entry lines already read. Reading never writes to the shared folder.
- The steward prunes entries older than ~90 days into `docs/logs/`.

## 9. Converting and migrating

- **Legacy solo card:** add `card_schema: bob/2` at the next update. Nothing else changes.
- **Solo to shared:** needs every person's agreement. If people kept separate cards for the same project, merge them into one. The agreed filename stays at the root; the other moves to `docs/archive/<stem>__archived-YYYY-MM-DD-HHMM.md`. Never delete it.

## 10. Push gate (optional hook)

A `git push` in a repo with a card is refused unless the card is committed, included in the push, and dated today. On a shared card the date checked is the pusher's own `people.<me>.last_updated`. Deliberate bypass: prefix the command with `BOB_GATE=skip`.
