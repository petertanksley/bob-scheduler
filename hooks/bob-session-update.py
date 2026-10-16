#!/usr/bin/env python3
"""
Bob Session Update Hook

Fires at session end (Stop event). If the current project has a status card (bob.md, or any card
tagged `card_schema: bob/...`; see bob_card.py), emits a one-line reminder to check whether status
fields need updating. On a shared card it points at the user's own section. Exits silently if there
is no card.

Hook Event: Stop
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import bob_card as bc  # noqa: E402

CYAN = "\033[0;36m"
NC = "\033[0m"


def main() -> int:
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        return 0
    cards, _ = bc.find_cards(project_dir)
    if not cards:
        return 0
    card = cards[0]
    fm = bc.frontmatter(card) or ""
    me = bc.identity()
    if (bc.field(fm, "shared") or "").lower() == "true" and me:
        where = f"your `## Person: {me}` section and people.{me} fields (leave other people's sections alone)"
    else:
        where = "effort_remaining, status, blockers, or 'This Week'"
    print(f"{CYAN}[bob]{NC} This project has a status card ({card.name}). Before closing, check whether {where} need updating.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
