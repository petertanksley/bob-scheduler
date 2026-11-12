# Bob: the Daily View

The one place the daily briefing is defined. Read by the main session for `/bob` and
`/bob daily` (no agent dispatch), and by the bob agent whenever it builds a daily.
Everything else about Bob lives in `~/.claude/agents/bob.md`.

## Procedure

1. Run the collector once:
   ```
   Rscript ~/.claude/skills/bob/collect.R daily --store
   ```
2. Write the view below from its facts sheet. Do not open any card: the sheet has the
   numbers (pressure, days, staleness, quadrant, badges) and, for every card that can
   reach Focus, its open This Week items (done items, long lines and Start Here are
   trimmed; Q2 and blocked cards show blockers only). Cards listed under "Details omitted"
   are quiet by rule; `collect.R lookup <words>` prints one in full if the user asks.
3. Invite reaction in one line.

The daily sheet is trimmed to fit one tool result (about 25 KB). If a large portfolio pushes
it over and the tool saves the output to a file instead, Read that file once, whole; do not
re-run the collector.

If the collector fails, say so in one line and dispatch the bob agent in daily mode
instead (it has the manual fallback). If the sheet shows no registered projects, skip the
view and prompt the user to run `/bob add`.

## The view

Punchy. 5 minutes to review. Bob's voice.

```
## Today — [Day, Date]

**Available today:** [Xh] (after [standing blocks / events if any])
[If disruption in effect: "Adjusted: Xh remaining as of [time]"]

**Urgent:** [RED / overdue / due-today projects, and any deadline inside a week — name, days until deadline]

**Focus today:**
1. [Project] — [specific task]
2. [Project] — [specific task]
3. [Project] — [specific task, max 4]

**Important, not urgent (don't let this slide):** [importance: high projects with GREEN/no-deadline pressure, especially any stale 2+ weeks or absent from Focus above]
[Omit this line entirely if none qualify]

**Exploratory slot:** [project/topic] — [~Xh]
[Omit if RED or YELLOW conflicts consume available time]

**Blocked:** [project] — [blocker]

**Waiting on you / you're waiting on:** [shared cards only — cross-person waits, e.g. "ben is waiting on you for the coding rules"]
[Omit if none]

**Changed since you last looked:** [shared cards only — "[Project]: ben updated their section (data pull landed)"]
[Omit if none]

**Mail:** [N unread across shared projects — `/bob mail` to read]
[Omit if none]

**Conflict copies:** [card conflict copies found, with filenames]
[Omit if none]

**Idea backlog:** [N idea(s) available — `/bob ideas` to review]
[Omit this line if future-projects.md has no entries]
```

## Rules the view depends on

- **The sheet reports facts; judgement is yours.** Which three or four things go in
  Focus, what the Q2 line says, whether a RED on a paused or low-intensity card matters
  today. Take Focus tasks from This Week, and make them specific.
- **Do not make priority decisions for the user and do not invent deadlines or estimates.**
  Surface, let them decide.
- **Shared cards:** Focus and This Week come from the user's own person section only. Never
  list another person's tasks as theirs. Their work shows up only through the waits line.
- **Queue cards:** each open row is its own entry, labelled `[Queue name] › [ID]`, with
  pressure from that row's `Due`. A row with `Due: TBD` appears as "needs a due date".
- **Pressure `n/a` with a deadline** means effort was not estimated in hours, not that
  there is no clock. Treat a near one as urgent and say the estimate is missing.
- **Q3 (urgent, not important):** still show it, annotated, so the user can weigh whether
  it deserves the hours.
- **Blocking others:** mark `[BLOCKING]`; someone is waiting on the user.
- **Grants:** `awarded` gets a one-line note ("Grant awarded — needs active setup").
  `submitted` / `under_review` stay out of Focus unless a specific action is needed.
  `REPORT-DUE` is its own clock; mention it when it is inside 30 days.
- **Exploratory work** never displaces deadline items; it holds its slot only when no RED
  or YELLOW conflict eats the day.
- **Same-day disruption** ("kids are sick", "signing off at 2"): acknowledge, ask how
  much time is left if not stated, recompute available hours, and cut Focus to the one or
  two things that most need finishing. Conversational only; nothing is written to
  `calendar.md` unless it turns out to recur.

## What the daily path does not do

It reads; it does not write. If the user's reaction means a card, the registry or the
calendar should change (a task done, a deadline moved, a new project, a reminder),
dispatch the bob agent in the matching mode (`update <project>`, `add`, `remind`,
`event`, `review`, `mail send`). The agent holds the card-writing rules (size budget,
shared-card protocol, queue rollups); never edit a card directly from here.
