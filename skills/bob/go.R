#!/usr/bin/env Rscript
# go.R -- /bob go: open a fresh Claude Code session inside a registered project.
#
# Usage: Rscript go.R <project query | absolute path> [--window | --terminal] [--bare] [--dry-run]
#
# Matches the query against the Active sections of ~/.claude/bob/registry.md and
# registry-local.md (folder name first, then display name), then copies
# `cd <path> && claude "<orientation prompt>"` to the clipboard for pasting into a
# new VS Code terminal tab. The project's status card is bob.md or any root .md
# tagged `card_schema: bob/<n>`; the prompt names whichever it finds. A session launched in the project loads its CLAUDE.md,
# memory and history, which a mid-session cd cannot do.
#
#   --window   open the folder in its own VS Code window with a Claude panel instead
#   --terminal open a new Terminal.app window running the command instead
#   --bare     start claude with no orientation prompt
#   --dry-run  print the match and the command, launch nothing
#   --suggest  print the card's next tasks and the models past sessions used, launch nothing
#   --model <alias> (or --model=<alias>, --fable, --opus, --sonnet, --haiku)
#              start the session on that model. With no flag, a `model:` line in
#              the project card's frontmatter is used; with neither, the default.
#              Not available with --window (the VS Code URI cannot carry a model).
#   --advisor <alias> (or --advisor=<alias>)
#              pair the session's model with a stronger advisor model it can consult
#              mid-task (Claude Code's experimental advisor; the launch command gets
#              `--advisor <alias>`). With no flag, an `advisor:` line in the card's
#              frontmatter is used. `--advisor off` launches without one even if the
#              card names one. Not available with --window.
#
# Exit codes: 0 launched (or dry run), 1 no match / bad path, 2 ambiguous
# (candidates printed one per line as "name<TAB>path").
# macOS only: uses osascript and open.

args  <- commandArgs(trailingOnly = TRUE)

# ---- Model --------------------------------------------------------------------
# --model <alias>, --model=<alias>, or the shorthands --fable / --opus / --sonnet / --haiku.
# Pulled out of args first so the alias is not mistaken for a query word.
model <- ""
i <- which(args == "--model")
if (length(i) > 0 && i[1] < length(args)) {
  model <- args[i[1] + 1]
  args  <- args[-c(i[1], i[1] + 1)]
}
eq <- grep("^--model=", args)
if (length(eq) > 0) {
  model <- sub("^--model=", "", args[eq[1]])
  args  <- args[-eq]
}
short <- intersect(args, c("--fable", "--opus", "--sonnet", "--haiku"))
if (length(short) > 0) {
  model <- sub("^--", "", short[1])
  args  <- setdiff(args, short)
}
if (nzchar(model) && !grepl("^[][A-Za-z0-9._-]+$", model)) {
  cat(sprintf("Not a usable model name: '%s'\n", model))
  quit(status = 1)
}

# ---- Advisor ------------------------------------------------------------------
# --advisor <alias> or --advisor=<alias>; "off" (or "none") means no advisor, card or not.
advisor <- ""
i <- which(args == "--advisor")
if (length(i) > 0 && i[1] < length(args)) {
  advisor <- args[i[1] + 1]
  args    <- args[-c(i[1], i[1] + 1)]
}
eq <- grep("^--advisor=", args)
if (length(eq) > 0) {
  advisor <- sub("^--advisor=", "", args[eq[1]])
  args    <- args[-eq]
}
if (nzchar(advisor) && !grepl("^[][A-Za-z0-9._-]+$", advisor)) {
  cat(sprintf("Not a usable advisor model name: '%s'\n", advisor))
  quit(status = 1)
}
advisor_off <- tolower(advisor) %in% c("off", "none")

flags <- args[startsWith(args, "--")]
query <- trimws(paste(args[!startsWith(args, "--")], collapse = " "))
if (!nzchar(query)) {
  cat("usage: go.R <project> [--model <alias>] [--advisor <alias>|off] [--window | --terminal] [--bare] [--dry-run]\n")
  quit(status = 1)
}

# ---- Registry -----------------------------------------------------------------

read_active <- function(file) {
  if (!file.exists(file)) return(NULL)
  lines <- readLines(file, warn = FALSE)
  heads <- grep("^## ", lines)
  start <- grep("^## Active", lines)
  if (length(start) == 0) return(NULL)
  end   <- c(heads[heads > start[1]], length(lines) + 1)[1] - 1
  lines <- lines[start[1]:end]
  # Two row formats: registry.md uses "- **Name** → `path`"; registry-local.md uses "- Name | path"
  rows  <- regmatches(lines, regexec("^- \\*\\*(.+?)\\*\\*.*?`([^`]+)`", lines))
  rows2 <- regmatches(lines, regexec("^- ([^|`*]+?) \\| (/.+?)\\s*$", lines))
  rows  <- Filter(function(m) length(m) == 3, c(rows, rows2))
  data.frame(name = trimws(vapply(rows, `[`, "", 2)),
             path = trimws(vapply(rows, `[`, "", 3)))
}

reg <- rbind(read_active(path.expand("~/.claude/bob/registry.md")),
             read_active(path.expand("~/.claude/bob/registry-local.md")))

# ---- Match --------------------------------------------------------------------

if (startsWith(query, "/")) {
  hit <- data.frame(name = basename(query), path = query)
} else {
  norm  <- function(x) gsub("[^a-z0-9]+", " ", tolower(x))
  q     <- norm(query)
  words <- strsplit(trimws(q), " +")[[1]]
  base  <- norm(basename(reg$path))
  base2 <- trimws(sub("^(proj|data) ", "", base))
  name  <- norm(reg$name)
  has_all <- function(x) vapply(x, function(s) all(vapply(words, grepl, TRUE, s, fixed = TRUE)), TRUE)
  tiers <- list(
    trimws(base) == trimws(q) | base2 == trimws(q),  # exact folder name
    has_all(base),                                   # all words in folder name
    has_all(name)                                    # all words in display name
  )
  hit <- reg[0, ]
  for (t in tiers) if (any(t)) { hit <- reg[t, ]; break }
}

if (nrow(hit) == 0) {
  cat(sprintf("No registered project matches '%s'.\n", query))
  quit(status = 1)
}
if (nrow(hit) > 1) {
  cat(sprintf("%s\t%s\n", hit$name, hit$path), sep = "")
  quit(status = 2)
}
if (!dir.exists(hit$path)) {
  cat(sprintf("Matched %s but the folder is missing: %s\n", hit$name, hit$path))
  quit(status = 1)
}

# ---- Card ---------------------------------------------------------------------
# The status card is bob.md, or any root-level .md whose frontmatter carries
# `card_schema: bob/<n>` (shared cards are often named after another agent). Same rule
# as collect.R and hooks/bob_card.py: bob.md first, then tagged files by name; README,
# CLAUDE, MEMORY, CHANGELOG, LICENSE and sync conflict copies are never cards.
frontmatter <- function(lines) {
  d <- which(trimws(lines) == "---")
  if (length(d) >= 2 && d[1] == 1) lines[seq_len(d[2])[-1][-(d[2] - 1)]] else character()
}
find_card <- function(dir) {
  bob <- file.path(dir, "bob.md")
  if (file.exists(bob)) return(bob)
  mds <- sort(list.files(dir, pattern = "\\.md$", full.names = TRUE))
  mds <- mds[!tolower(basename(mds)) %in% c("readme.md", "claude.md", "memory.md", "changelog.md", "license.md")]
  mds <- mds[!grepl("\\s\\(.+\\)$|-[A-Za-z0-9]+-\\d+$|\\s\\d+$", sub("\\.md$", "", basename(mds)), perl = TRUE)]
  for (f in mds) if (any(grepl("^card_schema:\\s*bob/", frontmatter(readLines(f, n = 200, warn = FALSE))))) return(f)
  ""
}
card <- find_card(hit$path)
card_lines <- if (nzchar(card)) readLines(card, warn = FALSE) else character()
card_fm    <- frontmatter(card_lines)
fm_value   <- function(key) {   # first `key: <alias>` in the frontmatter, "" if none
  m <- regmatches(card_fm, regexec(paste0("^", key, ":\\s*([][A-Za-z0-9._-]+)"), card_fm))
  m <- Filter(function(v) length(v) == 2, m)
  if (length(m)) m[[1]][2] else ""
}
# On a shared card the user's tasks sit under `## Person: <me>`; `me` comes from identity.md.
me <- ""
idf <- path.expand("~/.claude/bob/identity.md")
if (file.exists(idf)) {
  m <- regmatches(readLines(idf, warn = FALSE), regexec("^me:\\s*([A-Za-z0-9._-]+)", readLines(idf, warn = FALSE)))
  m <- Filter(function(v) length(v) == 2, m); if (length(m)) me <- m[[1]][2]
}
my_start <- if (nzchar(me)) grep(paste0("^## Person:\\s*", me, "\\s*$"), card_lines, ignore.case = TRUE) else integer()
shared   <- length(my_start) > 0

# ---- Suggest ------------------------------------------------------------------
# --suggest: print what the caller needs to recommend a model, then exit without
# launching: the card's type/status/deadline and next tasks, and which models the
# project's recent sessions ran on (read from ~/.claude/projects/<slug>/*.jsonl).

if ("--suggest" %in% flags) {
  cat(sprintf("%s\n%s\n", hit$name, hit$path))
  if (nzchar(card)) {
    fm <- grep("^(type|status|phase|priority|deadline|target|effort_remaining|model|advisor):", card_fm, value = TRUE)
    cat(sprintf("-- card: %s%s\n", basename(card), if (shared) sprintf(" (shared; section ## Person: %s)", me) else ""))
    cat(substr(fm, 1, 160), sep = "\n")
    # Solo card: `## <title>` sections. Shared card: `### <title>` inside the user's person section.
    cl <- card_lines; lvl <- "## "
    if (shared) {
      rest <- cl[(my_start[1] + 1):length(cl)]
      nxt  <- grep("^## ", rest)
      cl   <- rest[seq_len(if (length(nxt)) nxt[1] - 1 else length(rest))]; lvl <- "### "
    }
    sect <- function(title, n) {
      a <- grep(paste0("^", lvl, title), cl)
      if (length(a) == 0 || a[1] == length(cl)) return(invisible())
      rest <- cl[(a[1] + 1):length(cl)]
      b <- grep("^#{2,3} ", rest)
      body <- rest[seq_len(if (length(b)) b[1] - 1 else length(rest))]
      body <- body[nzchar(trimws(body)) & !grepl("^\\s*[-*] \\[[xX]\\]|^\\s*<!--", body)]
      cat(sprintf("-- %s\n", title)); cat(substr(head(body, n), 1, 200), sep = "\n")
    }
    sect("Start Here", 6); sect("This Week", 8)
  } else cat("-- card: none (no bob.md and no .md tagged card_schema: bob/2 in the project root)\n")
  slug <- gsub("[^A-Za-z0-9]", "-", normalizePath(hit$path, mustWork = FALSE))
  sdir <- file.path(path.expand("~/.claude/projects"), slug)
  logs <- if (dir.exists(sdir)) list.files(sdir, pattern = "\\.jsonl$", full.names = TRUE) else character()
  cat(sprintf("-- past sessions: %d\n", length(logs)))
  if (length(logs) > 0) {
    info <- file.info(logs); logs <- logs[order(info$mtime, decreasing = TRUE)]
    for (f in head(logs, 8)) {
      tx <- readLines(f, warn = FALSE)
      mm <- unlist(regmatches(tx, gregexpr('"model":"[^"]+"', tx)))
      mm <- sub('"model":"([^"]+)"', "\\1", mm); mm <- mm[mm != "<synthetic>"]
      tab <- sort(table(mm), decreasing = TRUE)
      cat(sprintf("%s  %s\n", format(file.info(f)$mtime, "%Y-%m-%d"),
                  if (length(tab)) paste(sprintf("%s x%d", names(tab), as.integer(tab)), collapse = ", ") else "(no model recorded)"))
    }
  }
  quit(status = 0)
}

# ---- Launch -------------------------------------------------------------------

card_name <- if (nzchar(card)) basename(card) else "bob.md"
orient <- paste0("Orient me: read this project's status card, ", card_name,
                 if (shared) paste0(" (my section is ## Person: ", me, "; also the project block and who is waiting on whom)") else " (Start Here Next Session, This Week, blockers)",
                 ", and any recent docs/logs entry, then give a five-line pickup. Do not start work.")
claude_bin <- Sys.which("claude")
if (!nzchar(claude_bin)) claude_bin <- "claude"

# No model flag: fall back to a `model:` line in the project card's frontmatter, if it has one.
model_src <- if (nzchar(model)) "flag" else ""
if (!nzchar(model)) {
  v <- fm_value("model")
  if (nzchar(v)) { model <- v; model_src <- paste0("card ", card_name) }
}

# Same for the advisor: flag first, then an `advisor:` line on the card. "off" wins over the card.
advisor_src <- if (nzchar(advisor)) "flag" else ""
if (advisor_off) advisor <- ""
if (!nzchar(advisor) && !advisor_off) {
  v <- fm_value("advisor")
  if (nzchar(v) && !tolower(v) %in% c("off", "none")) { advisor <- v; advisor_src <- paste0("card ", card_name) }
}

shell_cmd <- paste(c("cd", shQuote(hit$path), "&&", shQuote(claude_bin),
                     if (nzchar(model)) c("--model", shQuote(model)),
                     if (nzchar(advisor)) c("--advisor", shQuote(advisor)),
                     if (!"--bare" %in% flags) shQuote(orient)), collapse = " ")

if (!any(c("--window", "--terminal") %in% flags)) {
  # Default: copy the launch command for a new VS Code terminal tab in the
  # current window. Nothing outside VS Code can open a tab in an existing window,
  # so the user pastes it (Ctrl+Shift+` then Cmd+V, Enter).
  cmd <- c("printf %s", shQuote(shell_cmd), "| pbcopy")
} else if ("--window" %in% flags) {
  # Open the folder in its own VS Code window, then hand the Claude extension its
  # /open URI, which starts a Claude panel in the focused (new) window. The panel's
  # working directory is the window's folder, so the session lands in the project.
  cmd <- c("open", "-a", shQuote("Visual Studio Code"), shQuote(hit$path))
  uri <- "vscode://anthropic.claude-code/open"
  if (!"--bare" %in% flags) uri <- paste0(uri, "?prompt=", URLencode(orient, reserved = TRUE))
  cmd2 <- c("open", shQuote(uri))
} else {
  # Escape for an AppleScript double-quoted string
  as_str <- gsub('"', '\\\\"', gsub("\\\\", "\\\\\\\\", shell_cmd))
  script <- sprintf('tell application "Terminal"\n  activate\n  do script "%s"\nend tell', as_str)
  cmd <- c("osascript", "-e", shQuote(script))
}

cat(sprintf("%s\n%s\n", hit$name, hit$path))
if (nzchar(model)) {
  cat(sprintf("model: %s (from %s)%s\n", model, model_src,
              if ("--window" %in% flags) " -- ignored: --window cannot set a model" else ""))
} else {
  cat("model: session default\n")
}
if (nzchar(advisor)) {
  cat(sprintf("advisor: %s (from %s)%s\n", advisor, advisor_src,
              if ("--window" %in% flags) " -- ignored: --window cannot set an advisor" else ""))
} else {
  cat(sprintf("advisor: none%s\n", if (advisor_off) " (turned off by flag)" else ""))
}
if ("--dry-run" %in% flags) {
  cat(paste(cmd, collapse = " "), "\n")
  if (exists("cmd2")) cat(paste(cmd2, collapse = " "), "\n")
  quit(status = 0)
}
status <- system(paste(cmd, collapse = " "))
if (status == 0 && exists("cmd2")) {
  Sys.sleep(4)  # let the new window load and take focus before the URI arrives
  status <- system(paste(cmd2, collapse = " "))
}
quit(status = if (status == 0) 0 else 1)
