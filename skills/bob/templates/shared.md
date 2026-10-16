---
card_schema: bob/2
project: [Project Display Name]
type: research  # research | grant | writing | admin | web | exploratory; add that type's fields below
status: active
phase: null
shared: true
steward: [key]  # owns the project-level fields and prunes the project block
path: [/absolute/path/to/project]
deadline: null
target: null
blockers: null  # project-level, one line, current only
last_updated: YYYY-MM-DD  # project-level fields only
people:
  [key-a]:
    role: [PI / Co-I / RA / collaborator]
    priority: medium
    importance: null  # high | medium | low, this person's own view
    weekly_commitment: null
    effort_remaining: null
    last_updated: YYYY-MM-DD
  [key-b]:
    role: TBD
    priority: TBD
    importance: TBD
    weekly_commitment: TBD
    effort_remaining: TBD
    last_updated: YYYY-MM-DD
---

## Project

### Objectives

- [Primary goal]

### Team & Dependencies

| Key | Name | Role | Affiliation |
|-----|------|------|-------------|
| [key-a] | [Name] | [Role] | [Institution] |
| [key-b] | [Name] | [Role] | [Institution] |

### Upcoming Milestones

- [Date]: [Milestone]

### Notes

- [Standing project-level facts only, one line each. Mailbox: `.bob/mail.md`. Work-file ownership rule: see CLAUDE.md.]

## Person: [key-a]

### This Week

- [This person's tasks only]

### Waiting On / Waited On By

- none

### Start Here Next Session

- [≤ 10 lines]

## Person: [key-b]

### This Week

- TBD

### Waiting On / Waited On By

- none

### Start Here Next Session

- TBD

<!-- Shared card (bob/2). Edit only your own people.<key> entry and ## Person: <key> section; project-level fields are the steward's. Never drop fields or sections you don't recognize. Budget: project block ≤ 150 lines, each person section ≤ 60. Spec: ~/.claude/skills/bob/card-spec.md -->
