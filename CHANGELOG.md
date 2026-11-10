# Changelog

## v2026.11.10: `/bob go` picks the model

- **Model at launch.** `/bob go <project> --model <alias>` (or `--fable`, `--opus`, `--sonnet`, `--haiku`) adds `--model` to the copied launch command, so a session starts on the right model and never switches midstream. Not available with `--window`, whose VS Code link cannot carry a model.
- **Bob asks when you don't say.** With no model given, Bob asks once and recommends one, going by the project's next tasks and the models its past sessions ran on. `go.R --suggest` prints those facts (card type, Start Here, This Week, per-session models read from `~/.claude/projects/`) and launches nothing.
- **Per-project default.** An optional `model:` line in a card's frontmatter is used when no flag is given and skips the question. Documented in `card-spec.md`.
- `go.R` also reads registry rows written as `- Name | /path`, alongside the bold-name and backtick-path form.

## v2026.11.04: collector, prompt-free reads

- **`skills/bob/collect.R`.** One base-R script gathers the whole portfolio and prints a facts sheet: every card located and parsed (solo, shared, queue), deadline pressure, staleness, Eisenhower quadrant, line budgets, cross-person waits, "changed since you last looked", unread mail, calendar availability, pending notes and a data-problems list. The agent runs it once per view instead of opening cards one by one: a daily that took 14 shell calls and eight minutes now needs one call that returns in under a second, plus the write-up. `--store` saves the shared-card fingerprints and marks mail read. Modes: `daily`, `weekly`, `monthly`, `grants`, `scan`, `mail`, `lookup <words>`.
- **Prompt-free reads, documented properly.** The README, Quick Start and installer now say where `additionalDirectories` must live (user `~/.claude/settings.json`; a `settings.local.json` outside a git repository does not count when `blockReadsOutsideWorkingDirectories` is on) and add the narrow allow rule `Bash(Rscript ~/.claude/skills/bob/collect.R*)`, which survives auto mode where blanket rules are dropped. New `settings.permissions.example.json`.
- Agent and skill instructions: a "Start with the collector" section; each mode names its collector call; the manual procedure stays as the contract and the fallback when `Rscript` is missing.
- `.gitignore` for `__pycache__`.

## v2026.10.29: `/bob go`

- **`/bob go <project>`.** Switches projects by starting a fresh session inside the project folder, so its `CLAUDE.md`, memory and history load cleanly. The default copies the launch command for a new VS Code terminal tab; `--window` and `--terminal` open a new VS Code or Terminal.app window. Matcher: `skills/bob/go.R` (base R). macOS only.
- **Fixed the project-lookup launch line.** It printed `claude <path>`, which sends the path as the first prompt and leaves the session in the current folder. It now prints `cd "<path>" && claude`.

## v2026.10.16 — shared cards (bob/2)

- **Card format `card_schema: bob/2`.** Cards are found by frontmatter tag, not filename, so a renamed fork of Bob can keep cards under its own name. Untagged legacy cards are still read and get the tag at their next `update`. Spec: `skills/bob/card-spec.md`.
- **Shared projects.** One card per project, with a `steward`, a per-person `people:` map, and a `## Person: <key>` section each. Views show only your own tasks plus project-level state and cross-person waits, with a "changed since you last looked" line. `/bob add` asks whether a project is shared and who the steward is. New `templates/shared.md`.
- **Writing rules for shared cards.** Re-read before writing, edit only your own section, never rewrite the whole file, never drop unknown fields, prune only what you own, flag sync conflict copies.
- **Identity.** `~/.claude/bob/identity.md` (`me: <key>`, `agent: <name>`), local to each install. The installer asks for it.
- **Mailbox.** `.bob/mail.md`, an append-only mailbox per shared project; `/bob mail` and `/bob mail send`. Read state is local.
- **Hooks.** The push gate and session-end hook are tag-aware, and the gate checks the pusher's own `last_updated` on shared cards. New SessionStart hook announces the card and any unread mail in the folder you open.
- All templates carry `card_schema: bob/2`.

## v2026.09.18 — initial public release
