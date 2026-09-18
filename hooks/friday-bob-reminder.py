#!/usr/bin/env python3
"""
Friday Bob Reminder Hook

Fires at session start. If today is Friday and the reminder hasn't fired
yet today, emits a prompt to run /bob weekly.

Hook Event: SessionStart
Throttle: once per day (won't fire again if already shown today)
"""

import json
import sys
from datetime import date
from pathlib import Path

YELLOW = "\033[0;33m"
NC = "\033[0m"

CACHE_FILE = Path.home() / ".claude" / "sessions" / "friday-bob-reminder.json"


def read_cache() -> dict:
    try:
        return json.loads(CACHE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def write_cache(data: dict) -> None:
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(data))


def main() -> int:
    today = date.today()

    if today.weekday() != 4:  # 4 = Friday
        return 0

    cache = read_cache()
    if cache.get("last_reminded") == str(today):
        return 0

    write_cache({"last_reminded": str(today)})

    print(
        f"{YELLOW}[bob]{NC} It's Friday — good time for your weekly planning conference. "
        "Run /bob weekly when you're ready."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
