# Bob: a ten-minute Carpe Audience talk (plan)

Keyes's process, steps 2 to 8 (digest §3). Written before any slide.

## Audience, format, version

- **Audience:** a research team of six to ten. Mixed: some run Claude Code daily, some have never opened it. All carry a dozen or more live projects. They know the work; they do not know the tool.
- **Format:** campfire. Ten-minute slot after a team meeting, speaker holds the floor, questions at the end. One version; a 20-minute version would add the live demo of a daily.
- **Planned runtime:** 9 min 10 s est × 1.10 = 10 min 5 s. Fits a ten-minute slot with no questions inside it.

## Call to action (p. 39)

**Install Bob this week and have three project cards written by Friday morning, then type `/bob`.**

Tiered (p. 39):
1. Everyone: read the one-page summary; know what a card is, so a teammate's card makes sense when you open a shared folder.
2. Anyone who runs Claude Code: install (five minutes), register three real projects, run the daily on Friday.
3. Leads of shared projects: convert that project's card to a shared card with a steward and a person section each.

**Allies:** the repository and its Quick Start; the walkthrough page and the one-pager handed out at the end; the presenter, available for a fifteen-minute setup session with anyone who asks.

## Stories (prose, as spoken)

Each paragraph carries its type and an estimated runtime at 150 words a minute (R39, R42).

**Hook.** *Forty-one.* That is the number of live projects on my registry this morning, by actual count: grants in three different phases, two papers, a course, four datasets, the website, the admin folder. You are carrying some number like it. Nobody holds that in their head. What happens is that the loud ones, the ones with a date, eat the week, and the quiet ones, the ones that matter most and have no deadline precisely because nobody is forcing them, stop moving. This is ten minutes on one small habit that fixes that, and what it takes to set it up this week. I will not explain how Claude Code works inside; the walkthrough does that. *(Set the Stage · Hook · 45 s est)*

**The card.** Every project gets one short Markdown file at its root, called bob.md. Six fields on it decide where the project lands in your day. The deadline, the next date that actually bites. The hours of work left, a rough guess. The hours a week you can give it. Priority, how much you want it worked on now. Importance, how much it matters whether or not anything is due. And whether someone is waiting on you. That is it. Under those fields, three short sections: what you are doing this week, the next milestones, and a note called Start Here Next Session, which is the first thing your next session reads. The card stays under a hundred and fifty lines. It describes the present only. What happened goes into a dated log; how to work in the project goes into the instructions file. One rule holds everything up: if it is not on the card, it did not happen. A card that is not updated looks exactly like a project that did not move. *(Background · The card · 2 min 5 s est)*

**The day.** Four commands cover almost everything. In the morning, in a hub session, you type slash bob. It reads every card in under a second and gives you today's hours, what is red, three or four focus tasks, and a line for the important thing nobody is chasing. You pick the first project and type slash bob go and its name. That copies a launch line; new terminal tab, paste, enter, and a fresh session opens inside that project with its own instructions and a five-line pickup from its card. Nothing from the last project comes along, which is the point: a session belongs to the folder it started in. Before you close that tab, slash bob update. Bob writes what changed onto the card and moves the story into a log. And on Friday, slash bob weekly: hours next week, what is red, what has quietly slipped, and two questions about meetings and deadlines it does not know about yet. *(Background · The day · 1 min 50 s est)*

**Important, not urgent.** Here is the part I actually care about. Deadline pressure is arithmetic: hours left over hours a week against weeks to the date. Red, yellow, green. That measures urgency, and urgency is loud. Importance is a separate field, set by you, and Bob crosses the two. The project with high importance and no deadline gets surfaced in every briefing, on purpose, and the warning sharpens when it goes stale. This week mine read: *important, not urgent, untouched thirty-four days, zero hours a week, reset?* That paper feeds a manuscript due in December. Without the line it would have slid to January. Every briefing ends with the same three words, what looks wrong, because Bob surfaces and you decide. *(Background · Quiet projects · 1 min 25 s est)*

**Together.** Shared projects keep one card, never one per person. The lead is the steward and owns the top of it; everyone else has their own section and edits only that. Your daily shows your tasks, the project's state, and who is waiting on whom. Notes between people and their assistants go in a mailbox file in the project folder, one line each, append only. And one rule about where projects live, because it bites on day two: a project is on the synced drive or in a git checkout, never both. A git repository inside a syncing folder gets corrupted. The synced registry follows you between machines; a local one lists each machine's clones; pull before you run the daily. *(Background · Together · 1 min 20 s est)*

**Close.** Five minutes to install: clone, run the installer, two lines in your settings. Three cards by Friday: open a project, type slash bob add, answer roughly, about ten hours, two a week is plenty. Then type slash bob. So, back to the number. How many are you carrying? Three cards by Friday. *(Call to Action · Close · 45 s est)*

## Cadence worksheet (R35 to R38)

| Time | Story | Type | Slides |
|---|---|---|---|
| 0:00 | Hook | Set the Stage | title hook; 41; "The loud ones eat the week" |
| 0:45 | The card | Background | bob.md; six fields as a Power List (group, six lit, group: rapid-fire at 2 s each); 150; Start Here; "Not on the card? It didn't happen." |
| 2:50 | The day | Background | four commands as a Power List (group, four lit); "A fresh session for every project" |
| 4:40 | Quiet projects | Background | "Urgency is loud."; "Importance is a field."; quote line from a real daily (PAUSE); "What looks wrong?" |
| 6:05 | Together | Background | "One card per project."; "A mailbox, not an email thread."; "Synced drive or git. Never both."; "Pull, then /bob." |
| 7:25 | Close | Call to Action | 5 minutes; 3 cards; "Then type /bob"; callback "How many are you carrying?"; "Three cards by Friday." |
| 9:10 | end | | |

One change at least every 30 s throughout; the Power Lists give two rapid-fire runs (R38); stories run long, then shorter (R37).

## Napkins

Hook: *How many are you carrying?* · 41 · The loud ones eat the week
Card: bob.md · [deadline · effort · weekly hours · priority · importance · blocking] · 150 lines · Start Here Next Session · Not on the card? It didn't happen.
Day: [/bob · /bob go · /bob update · /bob weekly] · A fresh session for every project
Quiet: Urgency is loud. · Importance is a field. · "Important, not urgent. Untouched 34 days. Reset?" · What looks wrong?
Together: One card per project. · A mailbox, not an email thread. · Synced drive or git. Never both. · Pull, then /bob.
Close: 5 minutes · 3 cards · Then type /bob · How many are you carrying? · Three cards by Friday.

## Images

None in this version. The talk is a how-to; the type carries it, and ten minutes leaves no room for a photo beat that earns its place. A 20-minute version would add one photograph for the hook (a desk with too many open folders, the focal gap on a thirds line) and a live daily on screen.

## Numbers

All declared as constants in the deck YAML (nothing here is an estimate from a results file): 41 registered projects on the presenter's registry on 2026-11-04; 150, the card line budget; 34 days, the staleness the daily reported that morning; 5 minutes and 3 cards, the call to action.
