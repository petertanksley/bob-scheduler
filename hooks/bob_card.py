"""
bob_card.py — shared helpers for the Bob hooks (card_schema bob/2).

Not a hook itself. Imported by bob-card-detect.py, bob-push-gate.py and bob-session-update.py.

A status card is any root-level .md (not README/CLAUDE/MEMORY) whose frontmatter carries
`card_schema: bob/...`. Legacy fallback: frontmatter with `project:` + `last_updated:` + (`phase:` or
`status:`). This is what lets a descendant's card (any filename) be read exactly like a bob.md.
"""
import hashlib
import json
import os
import re
from pathlib import Path

BOB_HOME = Path(os.environ.get("CLAUDE_HOME", Path.home() / ".claude")) / "bob"
SKIP = {"readme.md", "claude.md", "memory.md", "changelog.md", "license.md"}
CONFLICT = re.compile(r"\s\(.+\)$|-[A-Za-z0-9]+-\d+$")  # "card (Someone's MacBook)", "bob-MACHINE-2"
MAIL_LINE = re.compile(r"^- (\d{4}-\d{2}-\d{2}) \| from: ([^|]+)\| to: ([^|]+)\| ([^|]+)\|(.*)$")


def frontmatter(path: Path) -> str | None:
    """Return the raw frontmatter block (between the first two --- lines), or None."""
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            head = f.read(6000)
    except OSError:
        return None
    m = re.match(r"---\s*\n(.*?)\n---\s*(\n|$)", head, re.S)
    return m.group(1) if m else None


def is_card(fm: str | None) -> bool:
    if not fm:
        return False
    if re.search(r"^card_schema:\s*bob/", fm, re.M):
        return True
    has = lambda k: re.search(rf"^{k}:", fm, re.M) is not None
    return has("project") and has("last_updated") and (has("phase") or has("status"))


def find_cards(root: str | Path) -> tuple[list[Path], list[Path]]:
    """(cards, conflict_copies) at the root of a directory. Cards sorted with bob.md first."""
    root = Path(root)
    cards, conflicts = [], []
    try:
        entries = sorted(p for p in root.iterdir() if p.is_file() and p.suffix == ".md")
    except OSError:
        return [], []
    for p in entries:
        if p.name.lower() in SKIP:
            continue
        if not is_card(frontmatter(p)):
            continue
        (conflicts if CONFLICT.search(p.stem) else cards).append(p)
    cards.sort(key=lambda p: (p.name != "bob.md", p.name))
    return cards, conflicts


def field(fm: str, key: str) -> str | None:
    m = re.search(rf"^{key}:\s*([^#\n]*)", fm, re.M)
    return m.group(1).strip() if m else None


def identity() -> str | None:
    try:
        txt = (BOB_HOME / "identity.md").read_text(encoding="utf-8")
    except OSError:
        return None
    m = re.search(r"^me:\s*([A-Za-z0-9_-]+)", txt, re.M)
    return m.group(1).lower() if m else None


def agent_name() -> str:
    """This install's agent name (`agent:` in identity.md; default "bob"). Mail addressed to it is ours."""
    try:
        txt = (BOB_HOME / "identity.md").read_text(encoding="utf-8")
    except OSError:
        return "bob"
    m = re.search(r"^agent:\s*([A-Za-z0-9_-]+)", txt, re.M)
    return m.group(1).lower() if m else "bob"


def person_last_updated(fm: str, key: str) -> str | None:
    """people.<key>.last_updated from a shared card, inline-map or block form."""
    m = re.search(rf"^\s+{re.escape(key)}:\s*\{{[^}}]*last_updated:\s*(\d{{4}}-\d{{2}}-\d{{2}})", fm, re.M)
    if m:
        return m.group(1)
    m = re.search(rf"^\s+{re.escape(key)}:\s*\n((?:\s{{4,}}.*\n?)+)", fm, re.M)
    if m:
        d = re.search(r"last_updated:\s*(\d{4}-\d{2}-\d{2})", m.group(1))
        return d.group(1) if d else None
    return None


def unread_mail(root: str | Path, me: str | None, agent_names: set[str]) -> list[str]:
    """Unread mailbox lines in <root>/.bob/mail.md addressed to me, my agent, or all."""
    box = Path(root) / ".bob" / "mail.md"
    if not box.exists():
        return []
    try:
        seen = json.loads((BOB_HOME / "mail-seen.json").read_text()).get(str(box.resolve()), [])
    except (OSError, ValueError):
        seen = []
    names = {n.lower() for n in agent_names | ({me} if me else set())} | {"all"}
    out = []
    for line in box.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = MAIL_LINE.match(line.strip())
        if not m:
            continue
        to = {t.strip().lower() for t in m.group(3).split(",")}
        if to & names and hashlib.sha1(line.strip().encode()).hexdigest() not in seen:
            out.append(line.strip())
    return out
