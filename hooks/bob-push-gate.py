#!/usr/bin/env python3
"""
bob-push-gate.py — PreToolUse hook (matcher: Bash)

Refuses `git push` in any repo that has a status card at its root (bob.md, or any card tagged
`card_schema: bob/...` such as a descendant agent's card; see bob_card.py) unless the card update is already in the
commits being pushed. The point: never push the content, then push a bob.md follow-up five minutes
later. The hook cannot write bob.md for you; it blocks, and the reason it returns
tells Claude what to do, so the bob update lands in the same push.

Allow when:
  - the command is not a git push, or
  - the repo has no bob.md at its root, or
  - the command is prefixed with `BOB_GATE=skip` (deliberate bypass), or
  - bob.md has no uncommitted changes AND is among the files changed between the upstream and HEAD
    AND its `last_updated:` is today. On a shared card (`shared: true`) the date checked is the pusher's
    own `people.<me>.last_updated` (identity from ~/.claude/bob/identity.md), so two people pushing the
    same repo don't fight over one line.
Otherwise deny with an actionable reason.

Wiring (user settings, ~/.claude/settings.json):
  "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command",
            "command": "python3 ~/.claude/hooks/bob-push-gate.py", "timeout": 15}]}]}
"""
import datetime as dt
import json
import os
import re
import shlex
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import bob_card as bc  # noqa: E402


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    sys.exit(0)


def git(cwd: str, *args: str) -> str | None:
    try:
        r = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=10)
    except Exception:
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if data.get("tool_name") != "Bash":
        sys.exit(0)
    cmd = str(data.get("tool_input", {}).get("command", ""))
    if not re.search(r"(^|[;&|]\s*|\s)git\s+(?:[^;&|]*\s)?push(\s|$)", cmd):
        sys.exit(0)
    if "BOB_GATE=skip" in cmd:
        sys.exit(0)

    # working directory: an explicit `cd <path>` earlier in the command wins over the session cwd
    cwd = data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    m = (re.search(r"git\s+-C\s+(\"[^\"]+\"|'[^']+'|\S+)\s+(?:[^;&|]*\s)?push", cmd)
         or re.search(r"(?:^|[;&|]\s*)cd\s+(\"[^\"]+\"|'[^']+'|\S+)", cmd))
    if m:
        try:
            cwd = os.path.expanduser(shlex.split(m.group(1))[0])
        except ValueError:
            pass

    root = git(cwd, "rev-parse", "--show-toplevel")
    if not root:
        sys.exit(0)
    cards, _ = bc.find_cards(root)
    if not cards:
        sys.exit(0)
    bob = str(cards[0])
    name = cards[0].name

    fix = (f"Update {name} first (This Week, Start Here Next Session, last_updated: today), commit it, then push, "
           "so the status update rides in the same push. Deliberate bypass: prefix the command with BOB_GATE=skip.")

    dirty = git(root, "status", "--porcelain", "--", name)
    if dirty:
        deny(f"{name} has uncommitted changes. Commit them before pushing. " + fix)

    upstream = git(root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    if upstream and git(root, "rev-list", "--count", f"{upstream}..HEAD") == "0":
        sys.exit(0)  # nothing to push (or tags only): nothing for the card to ride along with
    changed = git(root, "diff", "--name-only", f"{upstream}...HEAD") if upstream else git(root, "show", "--name-only", "--format=", "HEAD")
    changed_files = set((changed or "").splitlines())
    if name not in changed_files:
        ahead = git(root, "rev-list", "--count", f"{upstream}..HEAD") if upstream else "?"
        deny(f"{name} is not in the commits being pushed ({ahead} ahead of {upstream or 'no upstream'}). " + fix)

    today = dt.date.today().isoformat()
    try:
        with open(bob, encoding="utf-8") as f:
            head = f.read(4000)
    except OSError:
        sys.exit(0)
    fm = bc.frontmatter(cards[0]) or head
    me = bc.identity()
    if (bc.field(fm, "shared") or "").lower() == "true" and me:
        mine = bc.person_last_updated(fm, me)
        if mine is None:
            deny(f"{name} is a shared card with no people.{me}.last_updated. Add your entry, then commit. " + fix)
        if mine != today:
            deny(f"{name} is in the push but people.{me}.last_updated is {mine}, not {today}. Bump yours and commit. " + fix)
        sys.exit(0)
    d = re.search(r"^last_updated:\s*(\d{4}-\d{2}-\d{2})", fm, re.M)
    if d and d.group(1) != today:
        deny(f"{name} is in the push but last_updated is {d.group(1)}, not {today}. Bump it and amend or commit. " + fix)

    sys.exit(0)


if __name__ == "__main__":
    main()
