#!/usr/bin/env python3
"""
Bob Card Detect Hook

Fires at session start. If the session's directory has a status card at its root (any filename
carrying `card_schema: bob/...`, or a legacy bob-style card), tells Claude to read it first instead
of walking the tree. Also flags OneDrive/Dropbox conflict copies of the card and lists unread mail
from `.bob/mail.md` addressed to this user, their agent, or all. Read-only: never writes anything,
so it never marks mail as seen (Bob does that in `/bob mail`).

Hook Event: SessionStart
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import bob_card as bc  # noqa: E402


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}
    root = data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    cards, conflicts = bc.find_cards(root)
    if not cards and not conflicts:
        return 0

    me = bc.identity()
    lines = []
    for c in cards:
        fm = bc.frontmatter(c) or ""
        who = bc.field(fm, "maintained_by") or bc.field(fm, "steward")
        shared = (bc.field(fm, "shared") or "").lower() == "true"
        desc = f"`{c.name}`" + (f" (steward/maintainer: {who})" if who else "")
        desc += ", shared card: read the project block plus your own `## Person:` section" if shared else ""
        lines.append(f"Status card in this directory: {desc}. Read it first for the project rundown before exploring files.")
    if len(cards) > 1:
        lines.append(f"More than one card here ({', '.join(c.name for c in cards)}): they may disagree; say so rather than picking one silently.")
    for c in conflicts:
        lines.append(f"Possible sync conflict copy: `{c.name}`. Compare it with the card and tell the user before editing either.")

    mail = bc.unread_mail(root, me, {bc.agent_name()})
    if mail:
        lines.append(f"{len(mail)} unread item(s) in `.bob/mail.md` for you: " + " || ".join(m[2:] for m in mail[:5]))

    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                             "additionalContext": "[bob] " + "\n[bob] ".join(lines)}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
