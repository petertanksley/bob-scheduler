# Changelog

## v2026.10.16 — shared cards (bob/2)

- **Card format `card_schema: bob/2`.** Cards are found by frontmatter tag, not filename, so a renamed fork of Bob can keep cards under its own name. Untagged legacy cards are still read and get the tag at their next `update`. Spec: `skills/bob/card-spec.md`.
- **Shared projects.** One card per project, with a `steward`, a per-person `people:` map, and a `## Person: <key>` section each. Views show only your own tasks plus project-level state and cross-person waits, with a "changed since you last looked" line. `/bob add` asks whether a project is shared and who the steward is. New `templates/shared.md`.
- **Writing rules for shared cards.** Re-read before writing, edit only your own section, never rewrite the whole file, never drop unknown fields, prune only what you own, flag sync conflict copies.
- **Identity.** `~/.claude/bob/identity.md` (`me: <key>`, `agent: <name>`), local to each install. The installer asks for it.
- **Mailbox.** `.bob/mail.md`, an append-only mailbox per shared project; `/bob mail` and `/bob mail send`. Read state is local.
- **Hooks.** The push gate and session-end hook are tag-aware, and the gate checks the pusher's own `last_updated` on shared cards. New SessionStart hook announces the card and any unread mail in the folder you open.
- All templates carry `card_schema: bob/2`.

## v2026.09.18 — initial public release
