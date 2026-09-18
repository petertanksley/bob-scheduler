# bob.md vs. CLAUDE.md

A project directory can hold two different files that look similar (both Markdown, both "instructions for Claude") but serve different masters. Keeping them separate stops them from drifting out of sync with each other.

## bob.md — status, for Bob

- Lives at `[project_root]/bob.md`
- Read and written by the bob agent (`/bob`) — not by strategist, coder, writer, or any other pipeline agent
- Contains: `status`, `priority`, `importance`, `deadline`, `effort_remaining`, `weekly_commitment`, `blockers`, `blocking_others`, Team & Dependencies, This Week, Upcoming Milestones, phase (grants)
- Answers: *"Where does this project stand right now, and how urgently/importantly does it need your time?"*
- Time-varying by design — `last_updated` is expected to age and get refreshed via `/bob update`. A stale bob.md is a normal state, not a bug.

## CLAUDE.md (project-level) — conventions, for Claude Code

- Lives at `[project_root]/CLAUDE.md` — distinct from the user's global `~/.claude/CLAUDE.md`
- Read automatically by any Claude Code session working in that directory, by every agent that touches the project
- Contains: project-specific conventions, data locations, coding standards, compliance notes that affect *how work should be done*, architecture notes, pointers to key docs
- Answers: *"How should any agent behave while working inside this project?"*
- Relatively stable — changes only when a convention changes, not on every status update

## docs/logs/ — history, for whoever needs the why

- Lives at `[project_root]/docs/logs/YYYY-MM-DD_<slug>.md`, one file per session (plus `plans/` and `specs/` beneath it)
- Written at the end of a working session, or by Bob's prune step when it clears dated material out of bob.md
- Contains: what happened, what was decided, why, what was tried and abandoned, dated
- Answers: *"What happened on this project, and why is it the way it is?"*
- Append-only and unbounded — this is the one place that is allowed to grow

## The three together

| File | Question | Tense | Grows? |
|------|----------|-------|--------|
| `bob.md` | Where does this stand right now, and how much of your time does it need? | Present | No — ≤ 150 lines, overwritten to current state |
| `docs/logs/` | What happened, what was decided, why? | Past | Yes — one file per session |
| `CLAUDE.md` | How should any agent behave while working here? | Imperative | Rarely |

A decision is recorded in the log; bob.md carries only its consequence as a one-liner (`no textbooks; facilitator grades — see docs/logs/2026-08-17_…`). A future session that needs the reasoning follows the pointer.

## The rule

- **Never put scheduling/status content in CLAUDE.md.** Deadlines, priority, effort estimates, "this week" tasks belong in bob.md. Duplicating them into CLAUDE.md gives you two sources of truth that will eventually disagree.
- **Never put history in bob.md.** Dated session entries, completed milestones, last week's tasks, and the reasoning behind decisions go in `docs/logs/`. bob.md was written as "status, for Bob" and then accumulated 835 lines of dated Notes on one project (2026-08-28) because nothing ever removed anything. Bob's `update` mode now prunes on every run; see Size Discipline in `agents/bob.md`.
- **Never put workflow conventions in bob.md.** Coding standards, architecture notes, and "how to work in this repo" belong in CLAUDE.md. bob.md must stay short enough for Bob to read in one pass across dozens of projects — padding it with convention text or history defeats that. Budget: ≤ 150 lines.
- **If a fact matters to both**, put the full explanation in CLAUDE.md and drop a one-line pointer in bob.md's Notes section (e.g., "IRB pending — see CLAUDE.md") instead of copying the explanation twice.
- A project can have one, both, or neither file. Only projects tracked by the scheduler need bob.md; only projects with conventions worth stating for other agents need a project-level CLAUDE.md.

## Enforcement

`agents/bob.md`'s "What You Do NOT Do" section points back here. If you're writing to bob.md and the content you're about to add reads like a convention rather than a status fact, it belongs in CLAUDE.md instead.
