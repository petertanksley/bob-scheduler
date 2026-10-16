#!/usr/bin/env bash
# Install Bob into ~/.claude (or $CLAUDE_HOME if set).
#   ./install.sh          copy files (default; re-run to update the skill, agent, hooks)
#   ./install.sh --link   symlink skill/agent/hooks back to this checkout instead, so `git pull` updates them
# Existing data files in ~/.claude/bob/ are never overwritten.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"
MODE="copy"
[ "${1:-}" = "--link" ] && MODE="link"

place() {  # place <src> <dst>
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ "$MODE" = "link" ]; then
    rm -rf "$dst"; ln -s "$src" "$dst"; echo "  linked  $dst -> $src"
  else
    rm -rf "$dst"; cp -R "$src" "$dst"; echo "  copied  $dst"
  fi
}

echo "Installing Bob into $CLAUDE ($MODE mode)"
place "$HERE/skills/bob"   "$CLAUDE/skills/bob"
place "$HERE/agents/bob.md" "$CLAUDE/agents/bob.md"
for h in bob_card.py bob-card-detect.py bob-push-gate.py friday-bob-reminder.py bob-notes-reminder.py bob-session-update.py; do
  place "$HERE/hooks/$h" "$CLAUDE/hooks/$h"
done

echo "Data files (created only if absent):"
mkdir -p "$CLAUDE/bob"
for f in registry.md registry-local.md calendar.md notes.md future-projects.md; do
  if [ -e "$CLAUDE/bob/$f" ]; then
    echo "  kept    $CLAUDE/bob/$f"
  else
    cp "$HERE/bob-starter/$f" "$CLAUDE/bob/$f"; echo "  created $CLAUDE/bob/$f"
  fi
done

echo "Identity (who you are on shared cards):"
if [ -e "$CLAUDE/bob/identity.md" ]; then
  echo "  kept    $CLAUDE/bob/identity.md"
else
  if [ -t 0 ]; then
    read -r -p "  Your person key (short, lowercase, e.g. your first name): " ME
    read -r -p "  Your agent's name [bob]: " AGENT
  fi
  ME="${ME:-me}"; AGENT="${AGENT:-bob}"
  printf "me: %s\nagent: %s\n" "$(echo "$ME" | tr 'A-Z' 'a-z')" "$(echo "$AGENT" | tr 'A-Z' 'a-z')" > "$CLAUDE/bob/identity.md"
  echo "  created $CLAUDE/bob/identity.md (edit it any time)"
fi

cat <<MSG

Done. Two manual steps remain:

1. Hooks (optional but recommended). Merge settings.hooks.example.json into $CLAUDE/settings.json
   (or settings.local.json). It adds three SessionStart hooks (Friday nudge, note delivery, card +
   mailbox detection), a PreToolUse push gate on Bash, and one Stop hook. The push gate refuses a
   `git push` that doesn't carry the card update; bypass with BOB_GATE=skip.

2. Permissions. Bob reads bob.md files across every registered project, so add the parent
   directories of your projects to "permissions.additionalDirectories" in $CLAUDE/settings.json,
   along with "$CLAUDE/bob". Otherwise every read prompts.

Then start a new Claude Code session and run: /bob add
MSG
