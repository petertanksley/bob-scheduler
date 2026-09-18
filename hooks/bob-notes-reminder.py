#!/usr/bin/env python3
"""
Bob Notes Reminder Hook

Fires at session start. Checks ~/.claude/bob/notes.md for notes due today
or overdue. Surfaces them and moves them to the Delivered section.

Hook Event: SessionStart
"""

import re
import sys
from datetime import date
from pathlib import Path

CYAN = "\033[0;36m"
YELLOW = "\033[0;33m"
BOLD = "\033[1m"
NC = "\033[0m"

NOTES_FILE = Path.home() / ".claude" / "bob" / "notes.md"


def parse_pending(content: str) -> list[tuple[date, str, str]]:
    """Return list of (due_date, note_text, original_line) for Pending section."""
    notes = []
    in_pending = False
    for line in content.splitlines():
        if line.strip() == "## Pending":
            in_pending = True
            continue
        if line.startswith("## ") and in_pending:
            break
        if in_pending and line.startswith("- "):
            m = re.match(r"^- (\d{4}-\d{2}-\d{2})\s*\|\s*(.+)$", line)
            if m:
                notes.append((date.fromisoformat(m.group(1)), m.group(2).strip(), line))
    return notes


def main() -> int:
    if not NOTES_FILE.exists():
        return 0

    content = NOTES_FILE.read_text()
    today = date.today()

    pending = parse_pending(content)
    due = [(d, text, line) for d, text, line in pending if d <= today]
    if not due:
        return 0

    overdue = [(d, text) for d, text, _ in due if d < today]
    today_items = [(d, text) for d, text, _ in due if d == today]

    print(f"\n{BOLD}{CYAN}[bob] Notes for you:{NC}")
    if overdue:
        print(f"  {YELLOW}Overdue:{NC}")
        for d, text in overdue:
            print(f"    [{d}] {text}")
    if today_items:
        print(f"  {CYAN}Today:{NC}")
        for _, text in today_items:
            print(f"    {text}")
    print()

    # Move delivered notes out of Pending and into Delivered
    today_str = str(today)
    new_content = content
    for _, _, orig_line in due:
        delivered = f"{orig_line}  [delivered {today_str}]"
        new_content = new_content.replace(orig_line + "\n", "", 1)
        new_content = re.sub(r"(## Delivered\n)", f"\\1{delivered}\n", new_content)

    NOTES_FILE.write_text(new_content)
    return 0


if __name__ == "__main__":
    sys.exit(main())
