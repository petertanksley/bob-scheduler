#!/usr/bin/env python3
"""
Bob Session Update Hook

Fires at session end (Stop event). If the current project has a bob.md,
emits a one-line reminder to check whether status fields need updating.
Exits silently if no bob.md is found.

Hook Event: Stop
"""

import os
import sys
from pathlib import Path

CYAN = "\033[0;36m"
NC = "\033[0m"


def main() -> int:
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        return 0

    bob_md = Path(project_dir) / "bob.md"
    if not bob_md.exists():
        return 0

    print(
        f"{CYAN}[bob]{NC} This project has a bob.md. "
        "Before closing, check whether effort_remaining, status, blockers, "
        "or 'This Week' need updating."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
