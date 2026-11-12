#!/usr/bin/env Rscript
# collect.R -- gather the whole Bob portfolio in one pass and print a facts sheet.
#
# Usage: Rscript collect.R <mode> [query words] [--store] [--date YYYY-MM-DD]
#
#   mode    daily | weekly | monthly | quarterly | grants | scan | mail | lookup
#   --store write the shared-card fingerprints (card-seen.json) and, in mail mode,
#           mark the printed mail entries as read (mail-seen.json). Both files live in
#           ~/.claude/bob and nothing is ever written into a project folder.
#   --date  pretend today is this date (testing)
#
# The agent runs this ONCE per view instead of opening every card by hand. The sheet
# carries every number the view needs (deadline pressure, staleness, Eisenhower
# quadrant, line budgets, waits, unread mail, availability) plus the short body
# sections the view quotes. Rules implemented here are the ones written in
# agents/bob.md (Reading the Portfolio, Priority Logic, Reading the Calendar) and
# skills/bob/card-spec.md; the card-finding rules match hooks/bob_card.py.
#
# Base R only, no packages. Needs `shasum` (macOS, Linux) for fingerprints and mail
# read-state; without it those two features are skipped and the sheet says so.
# Exit codes: 0 ok, 1 usage error.

try(invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8")), silent = TRUE)
options(warn = 1)

# ---- Arguments -----------------------------------------------------------------

args  <- commandArgs(trailingOnly = TRUE)
STORE <- "--store" %in% args
dt_i  <- match("--date", args)
TODAY <- if (!is.na(dt_i) && length(args) > dt_i) as.Date(args[dt_i + 1]) else Sys.Date()
drop  <- which(args %in% c("--store") | seq_along(args) %in% c(dt_i, dt_i + 1))
pos   <- if (length(drop)) args[-drop] else args
MODE  <- if (length(pos)) tolower(pos[1]) else "daily"
QUERY <- if (length(pos) > 1) tolower(paste(pos[-1], collapse = " ")) else ""
if (MODE == "quarterly") MODE <- "monthly"
if (!MODE %in% c("daily", "weekly", "monthly", "grants", "scan", "mail", "lookup")) {
  cat("usage: collect.R <daily|weekly|monthly|grants|scan|mail|lookup <query>> [--store] [--date YYYY-MM-DD]\n")
  quit(status = 1)
}

BOB  <- file.path(Sys.getenv("CLAUDE_HOME", path.expand("~/.claude")), "bob")
SKIP <- c("readme.md", "claude.md", "memory.md", "changelog.md", "license.md")
CONFLICT <- "\\s\\(.+\\)$|-[A-Za-z0-9]+-\\d+$|\\s\\d+$"
SHASUM <- Sys.which("shasum")

# ---- Small helpers -------------------------------------------------------------

rl <- function(f) if (file.exists(f)) readLines(f, warn = FALSE, encoding = "UTF-8") else character()
trim <- function(x) gsub("^\\s+|\\s+$", "", x)
strip_comment <- function(x) trim(sub("\\s+#.*$", "", x))
comment_of <- function(x) { m <- regmatches(x, regexpr("\\s+#\\s*.*$", x)); if (length(m)) trim(sub("^\\s+#\\s*", "", m)) else "" }
is_null <- function(x) is.null(x) || is.na(x) || !nzchar(x) || tolower(x) %in% c("null", "none", "~", "tbd", "n/a", "-")
# A field counts as dated only when it STARTS with the date ("2026-11-15 (OSP routing...)"),
# optionally after "- " or "~". A date buried in prose ("approved 2026-10-09") is not a deadline.
first_date <- function(x) { if (is_null(x)) return(as.Date(NA)); m <- regmatches(x, regexec("^\\s*[-~]?\\s*(\\d{4}-\\d{2}-\\d{2})", x))[[1]]; if (length(m) == 2) as.Date(m[2]) else as.Date(NA) }
any_date <- function(x) { if (is_null(x)) return(as.Date(NA)); m <- regmatches(x, regexpr("\\d{4}-\\d{2}-\\d{2}", x)); if (length(m)) as.Date(m) else as.Date(NA) }
fmt_date <- function(d) if (is.na(d)) "" else format(d, "%Y-%m-%d")
nz <- function(x, alt = "") if (is.null(x) || length(x) == 0 || is.na(x)) alt else x
val <- function(fm, k) { v <- fm$fields[[k]]; if (is.null(v)) NA_character_ else v }
show <- function(fm, k) { v <- fm$raw[[k]]; if (is.null(v) || is_null(strip_comment(v))) NULL else v }

sha1_text <- function(x) {
  if (!nzchar(SHASUM)) return(NA_character_)
  tf <- tempfile(); on.exit(unlink(tf))
  writeBin(charToRaw(enc2utf8(x)), tf)
  h <- tryCatch(system2(SHASUM, c("-a", "1", shQuote(tf)), stdout = TRUE), error = function(e) "")
  if (length(h) && nzchar(h[1])) sub("\\s.*$", "", h[1]) else NA_character_
}

# Hours parser: "~10h", "1w", "2-3h", "1–2h", "5+h/wk", "~1h/mo", "1.2 person-months (~200h)"
parse_hours <- function(x) {
  if (is_null(x)) return(NA_real_)
  s <- tolower(x)
  s <- gsub("–|—", "-", s)
  if (grepl("^\\s*0\\s*h", s)) return(0)
  re <- "~?(\\d+(?:\\.\\d+)?)\\+?(?:\\s*(?:-|to)\\s*(\\d+(?:\\.\\d+)?))?\\s*(person-months?|person months?|pm|hours?|hrs?|h|days?|d|weeks?|wks?|w)\\b"
  m <- regmatches(s, regexec(re, s, perl = TRUE))[[1]]
  if (length(m) < 4) {
    # "(~200h)" style inside parentheses, or bare number: try any number followed by h
    m2 <- regmatches(s, regexec("(\\d+(?:\\.\\d+)?)\\s*h\\b", s, perl = TRUE))[[1]]
    if (length(m2) >= 2) return(as.numeric(m2[2]))
    return(NA_real_)
  }
  lo <- as.numeric(m[2]); hi <- if (nzchar(m[3])) as.numeric(m[3]) else lo
  n <- (lo + hi) / 2
  unit <- m[4]
  mult <- if (grepl("^(person|pm)", unit)) 160 else if (grepl("^(h|hr|hour)", unit)) 1 else if (grepl("^d", unit)) 8 else 40
  h <- n * mult
  if (grepl("/\\s*mo", s)) h <- h / 4.33
  h
}

# Minimal JSON reader/writer (only what card-seen.json / mail-seen.json need).
json_parse <- function(txt) {
  s <- paste(txt, collapse = "\n"); i <- 1L; n <- nchar(s)
  peek <- function() substr(s, i, i)
  ws <- function() while (i <= n && grepl("\\s", substr(s, i, i))) i <<- i + 1L
  str <- function() {
    i <<- i + 1L; out <- character()
    while (i <= n) {
      ch <- substr(s, i, i)
      if (ch == "\"") { i <<- i + 1L; return(paste(out, collapse = "")) }
      if (ch == "\\") { nx <- substr(s, i + 1, i + 1); out <- c(out, switch(nx, n = "\n", t = "\t", r = "\r", nx)); i <<- i + 2L; next }
      out <- c(out, ch); i <<- i + 1L
    }
    paste(out, collapse = "")
  }
  value <- function() {
    ws(); ch <- peek()
    if (ch == "{") { i <<- i + 1L; obj <- list(); ws()
      while (peek() != "}") { ws(); k <- str(); ws(); i <<- i + 1L; obj[[k]] <- value(); ws(); if (peek() == ",") i <<- i + 1L; ws() }
      i <<- i + 1L; return(obj) }
    if (ch == "[") { i <<- i + 1L; arr <- list(); ws()
      while (peek() != "]") { arr[[length(arr) + 1]] <- value(); ws(); if (peek() == ",") i <<- i + 1L; ws() }
      i <<- i + 1L; if (all(vapply(arr, is.character, TRUE))) return(unlist(arr)); return(arr) }
    if (ch == "\"") return(str())
    m <- regmatches(substr(s, i, n), regexpr("^(true|false|null|-?\\d+(\\.\\d+)?)", substr(s, i, n)))
    i <<- i + nchar(m); if (m == "true") TRUE else if (m == "false") FALSE else if (m == "null") NULL else as.numeric(m)
  }
  tryCatch(value(), error = function(e) list())
}
json_q <- function(x) paste0("\"", gsub("\"", "\\\\\"", gsub("\\\\", "\\\\\\\\", x)), "\"")
json_write <- function(x, ind = 0) {
  pad <- strrep("  ", ind)
  if (is.list(x) && !is.null(names(x))) {
    if (!length(x)) return("{}")
    body <- vapply(names(x), function(k) paste0(pad, "  ", json_q(k), ": ", json_write(x[[k]], ind + 1)), "")
    paste0("{\n", paste(body, collapse = ",\n"), "\n", pad, "}")
  } else if (is.character(x) && length(x) != 1 || is.list(x)) {
    if (!length(x)) return("[]")
    paste0("[", paste(vapply(x, json_q, ""), collapse = ", "), "]")
  } else json_q(as.character(x))
}
read_json <- function(f) { if (!file.exists(f) || file.size(f) == 0) return(list()); json_parse(rl(f)) }

# ---- Registry ----------------------------------------------------------------------

read_registry <- function(f, source) {
  l <- rl(f); s <- grep("^## Active", l)
  if (!length(l) || !length(s)) return(NULL)
  h <- grep("^## ", l); e <- c(h[h > s[1]], length(l) + 1)[1] - 1
  l <- l[s[1]:e]; l <- l[grepl("^- ", l)]
  if (!length(l)) return(NULL)
  rows <- lapply(l, function(x) {
    bt <- regmatches(x, regexec("`([^`]+)`", x))[[1]]
    if (length(bt) == 2) { path <- bt[2]; name <- regmatches(x, regexec("\\*\\*(.+?)\\*\\*", x))[[1]]; name <- if (length(name) == 2) name[2] else trim(sub("^- ", "", sub("→.*$", "", x))) }
    else if (grepl("\\|", x)) { parts <- strsplit(sub("^- ", "", x), "\\|")[[1]]; name <- trim(parts[1]); path <- trim(parts[length(parts)]) }
    else return(NULL)
    card <- regmatches(x, regexec("\\[card:\\s*([^\\]]+)\\]", x))[[1]]; card <- if (length(card) == 2) trim(card[2]) else NA_character_
    notes <- regmatches(x, gregexpr("\\[[^\\]]+\\]|\\((sub-project[^)]*)\\)", x))[[1]]
    notes <- notes[!grepl("^\\[card:", notes)]
    data.frame(name = name, path = path.expand(path), card_hint = card, note = paste(notes, collapse = " "), source = source, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}
registry <- rbind(read_registry(file.path(BOB, "registry.md"), "synced"),
                  read_registry(file.path(BOB, "registry-local.md"), "local"))
if (is.null(registry) || !nrow(registry)) {
  cat("REGISTRY EMPTY: no projects in", file.path(BOB, "registry.md"), "or registry-local.md. Tell the user to run /bob add.\n")
  quit(status = 0)
}

# ---- Identity ----------------------------------------------------------------------

id_lines <- rl(file.path(BOB, "identity.md"))
ME    <- tolower(nz(sub("^me:\\s*", "", grep("^me:", id_lines, value = TRUE))[1], ""))
AGENT <- tolower(nz(sub("^agent:\\s*", "", grep("^agent:", id_lines, value = TRUE))[1], "bob"))
if (!nzchar(AGENT)) AGENT <- "bob"

# ---- Cards ---------------------------------------------------------------------------

parse_frontmatter <- function(lines) {
  if (!length(lines) || trim(lines[1]) != "---") return(NULL)
  end <- which(trim(lines) == "---")[2]; if (is.na(end)) return(NULL)
  fm <- lines[2:(end - 1)]
  fields <- list(); raw <- list(); people <- list(); i <- 1
  while (i <= length(fm)) {
    ln <- fm[i]
    m <- regmatches(ln, regexec("^([A-Za-z_][A-Za-z0-9_]*):\\s*(.*)$", ln))[[1]]
    if (length(m) == 3) {
      key <- m[2]; v <- m[3]
      if (key == "people" && !nzchar(strip_comment(v))) {
        j <- i + 1; who <- NULL
        while (j <= length(fm) && grepl("^\\s+\\S", fm[j])) {
          pm <- regmatches(fm[j], regexec("^\\s{1,3}([A-Za-z0-9_-]+):\\s*(.*)$", fm[j]))[[1]]
          fp <- regmatches(fm[j], regexec("^\\s{4,}([A-Za-z0-9_-]+):\\s*(.*)$", fm[j]))[[1]]
          if (length(pm) == 3) { who <- tolower(pm[2]); people[[who]] <- list()
            if (grepl("^\\{", pm[3])) for (kv in strsplit(gsub("[{}]", "", pm[3]), ",")[[1]]) { kk <- strsplit(kv, ":")[[1]]; if (length(kk) >= 2) people[[who]][[trim(kk[1])]] <- strip_comment(paste(kk[-1], collapse = ":")) } }
          else if (length(fp) == 3 && !is.null(who)) people[[who]][[fp[2]]] <- strip_comment(fp[3])
          j <- j + 1
        }
        i <- j; next
      }
      fields[[key]] <- strip_comment(v); raw[[key]] <- v
    }
    i <- i + 1
  }
  list(fields = fields, raw = raw, people = people, end = end)
}
is_card <- function(fm) {
  if (is.null(fm)) return(FALSE)
  if (grepl("^bob/", nz(fm$fields$card_schema, ""))) return(TRUE)
  has <- function(k) !is.null(fm$fields[[k]])
  has("project") && has("last_updated") && (has("phase") || has("status"))
}
find_card <- function(dir, hint) {
  if (!dir.exists(dir)) return(list(card = NA, conflicts = character(), others = character()))
  if (!is.na(hint) && file.exists(file.path(dir, hint))) return(list(card = file.path(dir, hint), conflicts = character(), others = character()))
  mds <- list.files(dir, pattern = "\\.md$", full.names = TRUE)
  mds <- mds[!tolower(basename(mds)) %in% SKIP]
  cards <- character(); conflicts <- character()
  for (f in mds) {
    fm <- parse_frontmatter(rl(f)); if (!is_card(fm)) next
    stem <- sub("\\.md$", "", basename(f))
    if (grepl(CONFLICT, stem, perl = TRUE)) conflicts <- c(conflicts, f) else cards <- c(cards, f)
  }
  cards <- cards[order(basename(cards) != "bob.md", basename(cards))]
  list(card = if (length(cards)) cards[1] else NA, conflicts = conflicts, others = if (length(cards) > 1) cards[-1] else character())
}

# Split a body into level-2 sections; returns named list of character vectors (heading text -> lines).
sections <- function(lines, level = 2) {
  pat <- paste0("^", strrep("#", level), " ")
  h <- grep(pat, lines); if (!length(h)) return(list())
  out <- list()
  for (k in seq_along(h)) { s <- h[k]; e <- if (k < length(h)) h[k + 1] - 1 else length(lines); out[[trim(sub(pat, "", lines[s]))]] <- lines[s:e] }
  out
}
get_section <- function(secs, name) { k <- names(secs)[tolower(trim(names(secs))) == tolower(name) | startsWith(tolower(names(secs)), tolower(name))]; if (length(k)) secs[[k[1]]] else character() }
md_table <- function(lines) {
  t <- lines[grepl("^\\s*\\|", lines)]; if (length(t) < 3) return(NULL)
  cells <- lapply(t, function(x) trim(strsplit(sub("\\|\\s*$", "", sub("^\\s*\\|", "", x)), "\\|")[[1]]))
  hdr <- cells[[1]]; rows <- cells[-(1:2)]; rows <- rows[vapply(rows, function(r) length(r) == length(hdr), TRUE)]
  if (!length(rows)) return(NULL)
  df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE); names(df) <- hdr; df
}

PRI <- c(critical = 0, high = 1, medium = 2, low = 3)
pressure_of <- function(days, effort_h, weekly_h) {
  if (is.na(days)) return(list(color = "none", ratio = NA_real_))
  if (days == 0) return(list(color = "DUE-TODAY", ratio = Inf))
  if (days < 0) return(list(color = "OVERDUE", ratio = Inf))
  if (is.na(effort_h)) return(list(color = "n/a", ratio = NA_real_))
  if (effort_h == 0) return(list(color = "GREEN", ratio = 0))
  if (is.na(weekly_h) || weekly_h == 0) return(list(color = "RED", ratio = Inf))
  r <- (effort_h / weekly_h) / (days / 7)
  list(color = if (r >= 1) "RED" else if (r >= 0.7) "YELLOW" else "GREEN", ratio = r)
}

read_project <- function(reg) {
  p <- list(name = reg$name, path = reg$path, note = reg$note, source = reg$source, problems = character(), badges = character(),
            exists = dir.exists(reg$path), card = NA, conflicts = character(), fm = NULL, lines = character())
  if (!p$exists) { p$problems <- "folder missing"; p$badges <- "MISSING"; return(p) }
  fc <- find_card(reg$path, reg$card_hint)
  p$conflicts <- fc$conflicts
  if (length(fc$others)) p$problems <- c(p$problems, paste0("two candidate cards: ", basename(fc$card), " (used), ", paste(basename(fc$others), collapse = ", ")))
  if (is.na(fc$card)) { p$problems <- c(p$problems, "untracked: no status card at root"); p$badges <- "UNTRACKED"; return(p) }
  p$card <- fc$card; lines <- rl(fc$card); p$lines <- lines
  fm <- parse_frontmatter(lines); p$fm <- fm
  body <- lines[(fm$end + 1):length(lines)]
  f <- fm$fields
  p$type <- tolower(nz(f$type, "")); p$status <- tolower(nz(f$status, "")); p$phase <- nz(f$phase, "")
  p$shared <- tolower(nz(f$shared, "")) == "true"; p$queue <- tolower(nz(f$queue, "")) == "true"
  p$steward <- tolower(nz(f$steward, ""))
  # own fields (per person on shared cards)
  mine <- if (p$shared && nzchar(ME) && !is.null(fm$people[[ME]])) fm$people[[ME]] else NULL
  pick <- function(k) if (!is.null(mine) && !is.null(mine[[k]])) mine[[k]] else nz(f[[k]], NA_character_)
  p$priority <- tolower(nz(pick("priority"), "")); p$importance <- tolower(nz(pick("importance"), ""))
  p$weekly_raw <- pick("weekly_commitment"); p$effort_raw <- pick("effort_remaining")
  p$weekly_h <- parse_hours(p$weekly_raw); p$effort_h <- parse_hours(p$effort_raw)
  p$last_updated <- first_date(pick("last_updated")); p$project_last_updated <- first_date(f$last_updated)
  p$stale_days <- if (is.na(p$last_updated)) NA_integer_ else as.integer(TODAY - p$last_updated)
  if (p$shared && nzchar(ME) && is.null(mine)) p$problems <- c(p$problems, paste0("shared card has no people.", ME, " entry: shown as project-level only"))
  # deadline per grant phase rules
  ph <- tolower(trim(sub("[ (#].*$", "", p$phase)))
  p$grant_phase <- if (p$type == "grant") ph else ""
  p$excluded <- p$type == "grant" && ph %in% c("closed", "not_funded")
  dl <- first_date(f$deadline); dl_src <- "deadline"
  if (p$type == "grant") {
    if (ph == "developing") { d2 <- first_date(f$submission_deadline); if (!is.na(d2)) { dl <- d2; dl_src <- "submission_deadline" } }
    else if (ph %in% c("active", "no_cost_extension")) {
      # effort_remaining on an active grant spans the award, so the pace check runs against the
      # budget period end (or project_end); the next report is shown separately as its own clock.
      ds <- c(first_date(f$budget_period_end), first_date(f$project_end)); ds <- ds[!is.na(ds)]
      if (length(ds)) { dl <- min(ds); dl_src <- "budget_period_end/project_end" }
      nr <- first_date(f$next_report_due); if (!is.na(nr)) p$next_report <- nr
    }
    else if (ph %in% c("prospect", "submitted", "under_review", "awarded")) { dl <- as.Date(NA); dl_src <- paste0("none (grant phase ", ph, ")") }
  }
  p$deadline <- dl; p$deadline_src <- dl_src
  p$days <- if (is.na(dl)) NA_integer_ else as.integer(dl - TODAY)
  p$target <- first_date(f$target); p$target_days <- if (is.na(p$target)) NA_integer_ else as.integer(p$target - TODAY)
  pr <- pressure_of(p$days, p$effort_h, p$weekly_h)
  if (p$type == "grant" && ph == "closeout") pr <- list(color = "RED", ratio = NA_real_)
  if (p$type == "grant" && ph == "prospect") pr <- list(color = "none", ratio = NA_real_)
  p$pressure <- pr$color; p$ratio <- pr$ratio
  # badges
  if (!is_null(f$blocking_others)) p$badges <- c(p$badges, "BLOCKING")
  if (!is_null(f$blockers)) p$badges <- c(p$badges, "BLOCKED")
  if (p$status == "paused") p$badges <- c(p$badges, "PAUSED")
  rd <- first_date(f$resume_date); if (!is.na(rd) && rd <= TODAY && p$status == "paused") p$badges <- c(p$badges, paste0("RESUME-PASSED(", fmt_date(rd), ")"))
  if (p$type == "grant" && ph == "awarded") p$badges <- c(p$badges, "AWARDED-needs-setup")
  if (!is.null(p$next_report)) p$badges <- c(p$badges, paste0("REPORT-DUE(", fmt_date(p$next_report), ", ", as.integer(p$next_report - TODAY), "d)"))
  if (p$shared) p$badges <- c(p$badges, "SHARED"); if (p$queue) p$badges <- c(p$badges, "QUEUE")
  if (length(p$conflicts)) { p$badges <- c(p$badges, "CONFLICT-COPY"); p$problems <- c(p$problems, paste0("conflict copies: ", paste(basename(p$conflicts), collapse = ", "))) }
  if (!nzchar(p$importance) || is_null(p$importance)) { p$importance <- "?"; p$badges <- c(p$badges, "NO-IMPORTANCE") }
  if (!is.na(p$target) && is.na(dl) && p$target_days <= 14) p$badges <- c(p$badges, paste0(if (p$target_days < 0) "SOFT-TARGET-PASSED(" else "SOFT-TARGET(", fmt_date(p$target), ")"))
  # Eisenhower
  urgent <- p$pressure %in% c("RED", "YELLOW", "OVERDUE")
  p$quadrant <- if (p$importance == "high" && !urgent) "Q2 important-not-urgent" else if (p$importance == "high") "Q1" else if (p$importance %in% c("low", "medium") && urgent) "Q3 urgent-not-important" else if (p$importance == "?") "unknown" else "Q4"
  # sections and budgets
  secs <- sections(body)
  p$secs <- secs
  p$n_lines <- length(lines)
  if (p$shared) {
    ph_idx <- grep("^## Person:", lines)
    pb_end <- if (length(ph_idx)) ph_idx[1] - 1 else length(lines)
    p$project_block <- paste(lines[1:pb_end], collapse = "\n")
    p$person_text <- list(); p$person_lines <- integer()
    for (k in seq_along(ph_idx)) {
      s <- ph_idx[k]; e <- if (k < length(ph_idx)) ph_idx[k + 1] - 1 else length(lines)
      key <- tolower(trim(sub("^## Person:\\s*", "", lines[s])))
      p$person_text[[key]] <- paste(lines[s:e], collapse = "\n"); p$person_lines[key] <- e - s + 1
    }
    if (pb_end > 150) p$problems <- c(p$problems, paste0("project block over budget: ", pb_end, " lines (<= 150)"))
    for (k in names(p$person_lines)) if (p$person_lines[k] > 60) p$problems <- c(p$problems, paste0("person section ", k, " over budget: ", p$person_lines[k], " lines (<= 60)"))
    my <- if (nzchar(ME) && !is.null(p$person_text[[ME]])) strsplit(p$person_text[[ME]], "\n")[[1]] else character()
    p$my_section <- my
    ms <- sections(my, 3)
    p$this_week <- get_section(ms, "This Week"); p$start_here <- get_section(ms, "Start Here"); p$my_waits <- get_section(ms, "Waiting")
    p$milestones <- get_section(sections(strsplit(p$project_block, "\n")[[1]], 3), "Upcoming Milestones")
    p$cross_waits <- character()
    for (k in names(p$person_text)) {
      if (k == ME) next
      w <- get_section(sections(strsplit(p$person_text[[k]], "\n")[[1]], 3), "Waiting")
      w <- w[grepl("^\\s*[-*]", w) & !grepl("\\(none", w)]
      hit <- if (nzchar(ME)) w[grepl(paste0("\\b", ME, "\\b"), tolower(w))] else w
      if (length(hit)) p$cross_waits <- c(p$cross_waits, paste0("[", k, "] ", trim(hit)))
    }
    mw <- p$my_waits[grepl("^\\s*[-*]", p$my_waits) & !grepl("\\(none", p$my_waits)]
    if (length(mw)) p$cross_waits <- c(p$cross_waits, paste0("[", ME, "] ", trim(mw)))
  } else {
    p$this_week <- get_section(secs, "This Week"); p$start_here <- get_section(secs, "Start Here"); p$milestones <- get_section(secs, "Upcoming Milestones")
    nn <- length(get_section(secs, "Notes")); sh <- length(p$start_here)
    if (p$n_lines > 150) p$problems <- c(p$problems, paste0("over budget: ", p$n_lines, " lines (<= 150)"))
    if (nn > 21) p$problems <- c(p$problems, paste0("Notes over budget: ", nn - 1, " lines (<= 20)"))
    if (sh > 11) p$problems <- c(p$problems, paste0("Start Here over budget: ", sh - 1, " lines (<= 10)"))
  }
  if (!grepl("^bob/", nz(f$card_schema, ""))) p$problems <- c(p$problems, "legacy card: no card_schema tag (add at next update)")
  if (p$queue) {
    q <- md_table(get_section(secs, "Queue")); p$queue_rows <- q
    if (is.null(q)) p$problems <- c(p$problems, "queue: true but no parsable ## Queue table")
  }
  p
}

projects <- lapply(seq_len(nrow(registry)), function(i) read_project(registry[i, ]))

# ---- Ordering -----------------------------------------------------------------------

rank_of <- function(p) {
  if (!isTRUE(p$exists) || is.na(p$card)) return(c(9, 9, 9, 9, 9e9))
  pr <- match(p$pressure, c("OVERDUE", "DUE-TODAY", "RED", "YELLOW", "GREEN", "none", "n/a")); pr <- nz(pr, 7)
  # A deadline whose effort is not in hours (n/a) still has a clock: rank it by days left
  # (<= 7d with RED, <= 30d with YELLOW, later with GREEN) instead of below every "none".
  if (identical(p$pressure, "n/a") && !is.na(p$days)) pr <- if (p$days <= 7) 3 else if (p$days <= 30) 4 else 5
  st <- if (p$status == "active") 0 else if (p$status == "paused") 2 else 1
  pri <- nz(PRI[p$priority], 4); if ("BLOCKING" %in% p$badges) pri <- pri - 1
  ex <- if (p$type == "exploratory") 1 else 0
  c(if (isTRUE(p$excluded)) 8 else 0, st, pr, pri + ex * 0.5, nz(p$days, 9e9))
}
ord <- do.call(order, as.data.frame(t(vapply(projects, rank_of, numeric(5)))))
projects <- projects[ord]

# ---- Calendar, notes, ideas ---------------------------------------------------------

cal <- rl(file.path(BOB, "calendar.md"))
cal_secs <- sections(cal)
cfg <- function(sec, key, default) { l <- grep(paste0("^", key, ":"), get_section(cal_secs, sec), value = TRUE); if (length(l)) trim(sub("^[^:]+:\\s*", "", l[1])) else default }
daily_hours <- suppressWarnings(as.numeric(cfg("Work Defaults", "daily_hours", "8"))); if (is.na(daily_hours)) daily_hours <- 8
work_days_s <- cfg("Work Defaults", "work_days", "Mon-Fri")
wd_n <- if (grepl("mon.*fri", tolower(work_days_s))) 5 else max(1, length(strsplit(work_days_s, ",")[[1]]))
dur_hours <- function(x) {
  s <- tolower(x)
  if (grepl("no work|full day", s)) return(NA_real_)   # NA = whole day gone
  m <- regmatches(s, regexec("(\\d+(?:\\.\\d+)?)\\s*(h|hr|hour|min|m)\\b", s))[[1]]
  if (length(m) < 3) return(0)
  if (grepl("^m", m[3])) as.numeric(m[2]) / 60 else as.numeric(m[2])
}
blocks <- grep("^- ", get_section(cal_secs, "Standing Weekly Blocks"), value = TRUE)
weekly_blocked <- sum(vapply(blocks, function(b) { h <- dur_hours(b); if (is.na(h)) daily_hours else h }, 0))
ev_lines <- grep("^- \\d{4}-\\d{2}-\\d{2}", get_section(cal_secs, "Upcoming Events"), value = TRUE)
events <- do.call(rbind, lapply(ev_lines, function(x) {
  m <- regmatches(x, regexec("^- (\\d{4}-\\d{2}-\\d{2})(?: to (\\d{4}-\\d{2}-\\d{2}))?:\\s*(.*)$", x, perl = TRUE))[[1]]
  if (length(m) < 4) return(NULL)
  data.frame(start = as.Date(m[2]), end = as.Date(if (nzchar(m[3])) m[3] else m[2]), text = m[4], hours = dur_hours(m[4]), stringsAsFactors = FALSE)
}))
horizon <- grep("^- ", get_section(cal_secs, "Horizon Notes"), value = TRUE)
is_workday <- function(d) as.integer(format(d, "%u")) <= wd_n
window <- switch(MODE,
  weekly = { mon <- TODAY - (as.integer(format(TODAY, "%u")) - 1); c(mon, mon + 4) },
  monthly = c(TODAY, TODAY + 29),
  c(TODAY, TODAY))
days_in <- seq(window[1], window[2], by = "day"); wdays <- days_in[is_workday(days_in)]
gross <- length(wdays) * daily_hours
blocked <- weekly_blocked * length(wdays) / wd_n
ev_hours <- 0; ev_in <- character()
if (!is.null(events)) for (k in seq_len(nrow(events))) {
  ov <- days_in[days_in >= events$start[k] & days_in <= events$end[k]]; ov <- ov[is_workday(ov)]
  if (!length(ov)) next
  h <- if (is.na(events$hours[k])) daily_hours * length(ov) else events$hours[k]
  ev_hours <- ev_hours + h; ev_in <- c(ev_in, paste0(fmt_date(events$start[k]), if (events$end[k] != events$start[k]) paste0(" to ", fmt_date(events$end[k])) else "", ": ", events$text[k], " [-", h, "h]"))
}
available <- max(0, gross - blocked - ev_hours)
upcoming <- if (!is.null(events)) events[events$end >= TODAY & events$start <= TODAY + 90, ] else NULL
notes_pending <- { nl <- rl(file.path(BOB, "notes.md")); ns <- sections(nl); pn <- grep("^- \\d{4}-\\d{2}-\\d{2}", get_section(ns, "Pending"), value = TRUE)
  pn[vapply(pn, function(x) first_date(x) <= window[2], TRUE)] }
n_ideas <- length(grep("^## ", rl(file.path(BOB, "future-projects.md"))))

# ---- Fingerprints and mail -----------------------------------------------------------

seen_cards <- read_json(file.path(BOB, "card-seen.json")); changed <- character(); new_seen <- seen_cards
seen_mail <- read_json(file.path(BOB, "mail-seen.json")); new_mail_seen <- seen_mail
mail_unread <- list(); mail_total <- 0
MAIL_RE <- "^- (\\d{4}-\\d{2}-\\d{2}) \\| from: ([^|]+)\\| to: ([^|]+)\\| ([^|]+)\\|(.*)$"
for (p in projects) {
  if (!isTRUE(p$exists) || is.na(p$card)) next
  if (isTRUE(p$shared) && nzchar(SHASUM)) {
    fp <- list(project_block = substr(sha1_text(trim(p$project_block)), 1, 12))
    for (k in names(p$person_text)) if (k != ME) fp[[paste0("person:", k)]] <- substr(sha1_text(trim(p$person_text[[k]])), 1, 12)
    old <- seen_cards[[p$card]]
    if (is.null(old) || !identical(old$hash_version, "2")) changed <- c(changed, paste0(p$name, ": no v2 baseline stored yet (", if (STORE) "stored now" else "run with --store to start tracking", ")"))
    else for (k in names(fp)) { if (!identical(old[[k]], fp[[k]])) changed <- c(changed, paste0(p$name, ": ", if (k == "project_block") paste0("project block (steward ", p$steward, ")") else paste0(sub("person:", "", k), "'s section"), " changed since ", nz(old$baseline_stored, "?"))) }
    if (STORE) { fp$baseline_stored <- fmt_date(TODAY); fp$hash_version <- "2"; new_seen[[p$card]] <- fp }
  }
  box <- file.path(p$path, ".bob", "mail.md")
  if (file.exists(box)) {
    key <- normalizePath(box); seen <- nz(seen_mail[[key]], character()); if (is.list(seen)) seen <- unlist(seen)
    for (ln in trim(rl(box))) {
      m <- regmatches(ln, regexec(MAIL_RE, ln))[[1]]; if (length(m) < 6) next
      to <- tolower(trim(strsplit(m[4], ",")[[1]]))
      if (!any(to %in% c(ME, AGENT, "all"))) next
      mail_total <- mail_total + 1
      h <- sha1_text(ln); if (!is.na(h) && h %in% seen) next
      mail_unread[[p$name]] <- c(mail_unread[[p$name]], ln)
      if (STORE && MODE == "mail" && !is.na(h)) new_mail_seen[[key]] <- c(seen, h); seen <- nz(new_mail_seen[[key]], seen)
    }
  }
}
if (STORE) {
  if (length(new_seen)) writeLines(json_write(new_seen), file.path(BOB, "card-seen.json"))
  if (MODE == "mail" && length(new_mail_seen)) writeLines(json_write(new_mail_seen), file.path(BOB, "mail-seen.json"))
}
n_unread <- sum(vapply(mail_unread, length, 0L))

# ---- Output -------------------------------------------------------------------------

cat("# Bob facts sheet: ", MODE, " for ", format(TODAY, "%A, %Y-%m-%d"), "\n", sep = "")
cat("Identity: me=", if (nzchar(ME)) ME else "(missing: ask once and write ~/.claude/bob/identity.md)", ", agent=", AGENT,
    ". Projects registered: ", length(projects), " (", sum(registry$source == "synced"), " synced, ", sum(registry$source == "local"), " local). ",
    if (!nzchar(SHASUM)) "shasum not found: fingerprints and mail read-state skipped. " else "", "\n\n", sep = "")

cat("## Availability (", fmt_date(window[1]), if (window[2] != window[1]) paste0(" to ", fmt_date(window[2])) else "", ")\n", sep = "")
cat("- Gross: ", gross, "h (", length(wdays), " work day(s) x ", daily_hours, "h)\n", sep = "")
cat("- Standing blocks: -", round(blocked, 1), "h", if (length(blocks)) paste0(" (", paste(sub("^- ", "", blocks), collapse = "; "), ")") else " (none)", "\n", sep = "")
cat("- Events in window: -", ev_hours, "h", if (length(ev_in)) paste0("\n  - ", paste(ev_in, collapse = "\n  - ")) else " (none)", "\n", sep = "")
cat("- **Available: ", round(available, 1), "h**\n\n", sep = "")

# ---- Daily tiers ----------------------------------------------------------------------
# The daily sheet must stay small enough to be read in one tool result (well under 30 KB):
# all 49 cards verbatim was 130 KB. "full" = can reach Focus (This Week printed);
# "brief" = Q2 / blocked, one line in the view (blockers only); "skip" = named at the end.
DAILY_TOP <- 8; DAILY_DAYS <- 14
daily_tier <- function(i, p) {
  if (i <= DAILY_TOP || p$pressure %in% c("OVERDUE", "DUE-TODAY", "RED", "YELLOW") ||
      length(p$cross_waits) > 0 || isTRUE(p$queue) ||
      any(c("AWARDED-needs-setup", "REPORT-DUE", "RESUME-PASSED") %in% p$badges) ||
      (!is.na(p$days) && p$days <= DAILY_DAYS) || any(grepl("^SOFT-TARGET", p$badges)) ||   # near deadline even when pressure is n/a
      (p$status == "active" && p$priority %in% c("critical", "high"))) return("full")
  if (identical(p$quadrant, "Q2 important-not-urgent") || any(c("BLOCKED", "BLOCKING") %in% p$badges)) return("brief")
  "skip"
}
tier_of <- function(i, p) if (MODE == "daily") daily_tier(i, p) else "full"
clip <- function(x, n = 200) ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "\u2026"), x)

tbl_row <- function(i, p) {
  if (!isTRUE(p$exists) || is.na(p$card)) return(paste0("| ", i, " | ", p$name, " | | | | | | | | | | ", paste(p$badges, collapse = " "), " |"))
  dl <- if (!is.na(p$deadline)) paste0(fmt_date(p$deadline), " (", p$days, "d)") else ""
  tg <- if (!is.na(p$target)) paste0(fmt_date(p$target), " (", p$target_days, "d)") else ""
  pr <- p$pressure; if (!is.na(p$ratio) && is.finite(p$ratio)) pr <- paste0(pr, " ", format(round(p$ratio, 2), nsmall = 2))
  ph <- trim(sub("\\s*#.*$", "", p$phase)); if (nchar(ph) > 40) ph <- paste0(substr(ph, 1, 38), "..")
  hrs <- function(h, raw) if (is.na(h)) { if (is_null(raw)) "" else "?" } else paste0(round(h, 1), "h")
  paste0("| ", i, " | ", p$name, " | ", p$type, " | ", p$status, if (nzchar(ph)) paste0(" / ", ph) else "", " | ", p$priority, " | ", p$importance, " | ", pr, " | ", dl, " | ", tg, " | ",
         hrs(p$effort_h, p$effort_raw), " | ", hrs(p$weekly_h, p$weekly_raw), " | ", nz(p$stale_days, "?"), " | ", paste(p$badges, collapse = " "), " |")
}
if (!MODE %in% c("mail", "lookup")) {
  cat("## Projects (sorted: active first, then pressure, priority, deadline; excluded grants last)\n\n")
  cat("Pressure = (effort_h / weekly_h) / (days / 7): RED >= 1, YELLOW 0.7-0.99, GREEN < 0.7; none = no hard deadline; n/a = effort not estimated in hours; a 0h weekly with a deadline is RED. An n/a card with a deadline sorts by days left (<= 7d with RED, <= 30d with YELLOW, else GREEN). ",
      "Effort/Weekly are parsed hours (? = text that gave no hours; see the detail block for the wording). Stale = days since (your) last_updated. Phase text truncated.\n\n")
  cat("| # | Project | Type | Status / phase | Pri | Imp | Pressure | Deadline (days) | Soft target | Effort | Weekly | Stale | Badges |\n|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
  for (i in seq_along(projects)) if (tier_of(i, projects[[i]]) != "skip") cat(tbl_row(i, projects[[i]]), "\n", sep = "")
  if (MODE == "daily") cat("\n(daily: quiet cards are left out of this table and named under \"Details omitted\")\n")
  cat("\n")
}

q2 <- Filter(function(p) isTRUE(p$exists) && !is.na(p$card) && !isTRUE(p$excluded) && p$quadrant == "Q2 important-not-urgent", projects)
if (length(q2)) { cat("## Important, not urgent (Q2 check)\n"); for (p in q2) cat("- ", p$name, ": importance high, pressure ", p$pressure, ", stale ", nz(p$stale_days, "?"), "d, weekly ", clip(nz(p$weekly_raw, "?"), if (MODE == "daily") 40 else 9999), if (nz(p$stale_days, 0) >= 14) "  <-- stale 2+ weeks" else "", "\n", sep = ""); cat("\n") }
q3 <- Filter(function(p) isTRUE(p$exists) && !is.na(p$card) && p$quadrant == "Q3 urgent-not-important", projects)
if (length(q3)) { cat("## Urgent, not important (annotate, do not hide)\n"); for (p in q3) cat("- ", p$name, ": importance ", p$importance, ", pressure ", p$pressure, "\n", sep = ""); cat("\n") }

queue_rows_out <- function(p) {
  q <- p$queue_rows; if (is.null(q)) return(invisible())
  cat("Queue rows (each is its own entry: `", p$name, " > <ID>`):\n\n", sep = "")
  dcol <- names(q)[tolower(names(q)) == "due"]; tcol <- names(q)[tolower(names(q)) == "target"]
  for (r in seq_len(nrow(q))) {
    due <- if (length(dcol)) first_date(q[r, dcol]) else as.Date(NA); tg <- if (length(tcol)) first_date(q[r, tcol]) else as.Date(NA)
    cat("- ", paste(paste0(names(q), ": ", unlist(q[r, ])), collapse = " | "),
        if (!is.na(due)) paste0("  => due in ", as.integer(due - TODAY), "d") else if (length(dcol) && is_null(q[r, dcol])) "  => NEEDS A DUE DATE" else "",
        if (!is.na(tg)) paste0("; target in ", as.integer(tg - TODAY), "d") else "", "\n", sep = "")
  }
  cat("\n")
}

detail <- function(i, p, full = FALSE, brief = FALSE) {
  cat("## [", i, "] ", p$name, "\n", sep = "")
  cat("Path: ", p$path, if (!is.na(p$card)) paste0("  |  Card: ", basename(p$card), " (", p$n_lines, " lines)") else "", "\n", sep = "")
  if (!isTRUE(p$exists) || is.na(p$card)) { cat("Problems: ", paste(p$problems, collapse = "; "), "\n\n", sep = ""); return(invisible()) }
  f <- p$fm$raw
  keys <- c("project", "type", "status", "phase", "priority", "importance", "deadline", "target", "effort_remaining", "weekly_commitment", "last_updated", "resume_date", "blockers", "blocking_others", "waiting_on",
            "funder", "mechanism", "submission_deadline", "award_date", "project_start", "project_end", "budget_period_end", "next_report_due", "total_budget", "steward", "maintained_by")
  for (k in keys) { v <- show(p$fm, k); if (!is.null(v)) cat("- ", k, ": ", v, "\n", sep = "") }
  if (isTRUE(p$shared)) {
    cat("- shared: steward=", p$steward, "; people=", paste(names(p$fm$people), collapse = ", "), "\n", sep = "")
    if (nzchar(ME) && !is.null(p$fm$people[[ME]])) cat("- people.", ME, ": ", paste(paste0(names(p$fm$people[[ME]]), "=", unlist(p$fm$people[[ME]])), collapse = "; "), "\n", sep = "")
  }
  cat("- computed: deadline from ", p$deadline_src, if (!is.na(p$days)) paste0(", ", p$days, " days left") else "", "; effort ", nz(round(p$effort_h, 1), "?"), "h; weekly ", nz(round(p$weekly_h, 1), "?"), "h; pressure ", p$pressure,
      if (!is.na(p$ratio) && is.finite(p$ratio)) paste0(" (ratio ", round(p$ratio, 2), ")") else "", "; stale ", nz(p$stale_days, "?"), "d; quadrant ", p$quadrant, "\n", sep = "")
  if (length(p$note) && nzchar(p$note)) cat("- registry note: ", p$note, "\n", sep = "")
  if (length(p$problems)) cat("- PROBLEMS: ", paste(p$problems, collapse = "; "), "\n", sep = "")
  if (isTRUE(p$queue)) { cat("\n"); queue_rows_out(p) }
  if (brief) { cat("(body omitted in daily: Q2/blocked line only)\n\n"); return(invisible()) }
  if (full) { cat("\n```\n", paste(p$lines, collapse = "\n"), "\n```\n\n", sep = ""); return(invisible()) }
  if (isTRUE(p$shared)) {
    if (length(p$my_section)) cat("\n", paste(p$my_section, collapse = "\n"), "\n", sep = "") else cat("\n(no ## Person: ", ME, " section)\n", sep = "")
    if (length(p$milestones) && MODE != "daily") cat("\n", paste(p$milestones, collapse = "\n"), "\n", sep = "")
    if (length(p$cross_waits)) cat("\nCross-person waits:\n", paste0("- ", p$cross_waits, collapse = "\n"), "\n", sep = "")
  } else {
    for (s in list(p$this_week, p$start_here, if (MODE != "daily") p$milestones)) if (length(s)) cat("\n", paste(s, collapse = "\n"), "\n", sep = "")
  }
  cat("\n")
}

# Weekly / monthly detail. The table already carries status, priority, importance, dates,
# parsed hours, staleness and badges, so the block prints only what it lacks, and leaves out
# what planning does not use: done items and Start Here (session-resume notes; `lookup`
# prints a card in full). Quiet cards (the ones daily only names) get blockers + milestones.
not_done <- function(x) x[!grepl("^\\s*[-*] \\[[xX]\\]", x)]
detail_plan <- function(i, p) {
  quiet <- daily_tier(i, p) == "skip"
  cat("## [", i, "] ", p$name, if (quiet) "  (quiet: blockers + milestones only)" else "", "\n", sep = "")
  if (!isTRUE(p$exists) || is.na(p$card)) { cat("Problems: ", paste(p$problems, collapse = "; "), "\n\n", sep = ""); return(invisible()) }
  keys <- c("effort_remaining", "weekly_commitment", "resume_date", "blockers", "blocking_others", "waiting_on",
            "funder", "mechanism", "submission_deadline", "award_date", "project_start", "project_end", "budget_period_end", "next_report_due", "total_budget")
  for (k in keys) {
    v <- show(p$fm, k); if (is.null(v)) next
    if (k %in% c("effort_remaining", "weekly_commitment") && nchar(v) <= 12) next   # a bare number: the table has it
    cat("- ", k, ": ", clip(v, 300), "\n", sep = "")
  }
  cat("- computed: deadline from ", p$deadline_src, if (!is.na(p$ratio) && is.finite(p$ratio)) paste0("; ratio ", round(p$ratio, 2)) else "", "; quadrant ", p$quadrant, "\n", sep = "")
  if (length(p$note) && nzchar(p$note)) cat("- registry note: ", p$note, "\n", sep = "")
  if (length(p$problems)) cat("- PROBLEMS: ", paste(p$problems, collapse = "; "), "\n", sep = "")
  if (isTRUE(p$queue)) { cat("\n"); queue_rows_out(p) }
  out <- function(x) if (length(x)) cat("\n", paste(x, collapse = "\n"), "\n", sep = "")
  if (isTRUE(p$shared)) {
    if (!quiet) { if (length(p$my_section)) out(not_done(drop_subsections(p$my_section, "start here"))) else cat("\n(no ## Person: ", ME, " section)\n", sep = "") }
    out(p$milestones)
    if (length(p$cross_waits)) cat("\nCross-person waits:\n", paste0("- ", p$cross_waits, collapse = "\n"), "\n", sep = "")
  } else {
    if (!quiet) { tw <- not_done(p$this_week); out(if (sum(nzchar(trim(tw))) > 1) tw else p$start_here) }   # no task list: fall back to Start Here
    out(p$milestones)
  }
  cat("\n")
}

# Daily detail: the table already carries status, priority, pressure, dates, hours and badges,
# so print only what it lacks: blockers/waits, unparsed effort wording, queue rows, This Week.
drop_subsections <- function(lines, pat) {
  out <- character(); skip <- FALSE
  for (ln in lines) { if (grepl("^#{2,4} ", ln)) skip <- grepl(pat, ln, ignore.case = TRUE); if (!skip) out <- c(out, ln) }
  out
}
detail_daily <- function(i, p, brief) {
  cat("## [", i, "] ", p$name, if (brief) "  (brief)" else "", "\n", sep = "")
  if (!isTRUE(p$exists) || is.na(p$card)) { cat("Problems: ", paste(p$problems, collapse = "; "), "\n\n", sep = ""); return(invisible()) }
  for (k in c("blockers", "blocking_others", "waiting_on")) { v <- show(p$fm, k); if (!is.null(v)) cat("- ", k, ": ", clip(v, 220), "\n", sep = "") }
  if (is.na(p$effort_h) && !is.na(p$days)) cat("- effort_remaining (no hours parsed): ", clip(nz(p$effort_raw, "?"), 120), "\n", sep = "")
  if (length(p$problems)) cat("- PROBLEMS: ", paste(p$problems, collapse = "; "), "\n", sep = "")
  if (isTRUE(p$queue)) { cat("\n"); queue_rows_out(p) }
  if (brief) { cat("\n"); return(invisible()) }
  body <- if (isTRUE(p$shared)) drop_subsections(p$my_section, "start here|milestone") else p$this_week
  body <- body[nzchar(trim(body)) & !grepl("^\\s*[-*] \\[[xX]\\]", body)]   # done items are not focus candidates
  if (sum(grepl("^\\s*([-*]|[0-9]+\\.)\\s", body)) == 0 && !isTRUE(p$shared)) body <- p$start_here[nzchar(trim(p$start_here))]   # no task list: fall back
  if (length(body) > 8) body <- c(body[1:8], paste0("(+", length(body) - 8, " more lines; lookup for the rest)"))
  if (length(body)) cat(paste(clip(body, 160), collapse = "\n"), "\n", sep = "")
  cat("\n")
}

if (MODE %in% c("daily", "weekly", "monthly")) {
  cat("## Project details (same order", if (MODE == "daily") "; daily: This Week for focus candidates, blockers only for Q2/blocked" else "; open This Week items + milestones; no Start Here, no done items; `lookup` for a full card", ")\n\n", sep = "")
  skipped <- character()
  for (i in seq_along(projects)) {
    p <- projects[[i]]; if (isTRUE(p$excluded)) next
    tier <- tier_of(i, p)
    if (tier == "skip") { skipped <- c(skipped, p$name); next }
    if (MODE == "daily") detail_daily(i, p, tier == "brief") else detail_plan(i, p)
  }
  if (length(skipped)) cat("## Details omitted in daily (", length(skipped), " cards, table row only; `collect.R lookup <words>` for one)\n",
                           paste0("- ", skipped, collapse = "\n"), "\n\n", sep = "")
}
if (MODE == "lookup") {
  if (!nzchar(QUERY)) { cat("lookup needs a query\n"); quit(status = 1) }
  hits <- Filter(function(p) { hay <- tolower(paste(p$name, basename(p$path), nz(p$fm$fields$project, ""), if (!is.null(p$queue_rows)) paste(unlist(p$queue_rows), collapse = " ") else ""))
    all(vapply(strsplit(QUERY, "\\s+")[[1]], function(w) grepl(w, hay, fixed = TRUE), TRUE)) }, projects)
  cat("## Lookup: ", length(hits), " match(es) for \"", QUERY, "\"\n\n", sep = "")
  for (p in hits) detail(match(p$name, vapply(projects, `[[`, "", "name")), p, full = TRUE)
  if (length(hits) == 1) cat("Launch: cd \"", hits[[1]]$path, "\" && claude\n\n", sep = "")
}
if (MODE == "grants") {
  g <- Filter(function(p) isTRUE(p$exists) && !is.na(p$card) && p$type == "grant", projects)
  cat("## Grants by phase\n\n| Grant | Funder | Mechanism | Phase | Key date | Days | Pressure | Next report | Budget period end | Total |\n|---|---|---|---|---|---|---|---|---|---|\n")
  for (p in g) { f <- p$fm$fields; cat("| ", p$name, " | ", nz(f$funder, ""), " | ", nz(f$mechanism, ""), " | ", p$grant_phase, " | ", fmt_date(p$deadline), " | ", nz(p$days, ""), " | ", p$pressure, " | ", nz(f$next_report_due, ""), " | ", nz(f$budget_period_end, ""), " | ", nz(f$total_budget, ""), " |\n", sep = "") }
  cat("\n")
}
if (MODE == "scan") {
  cat("## Scan\n\n")
  st <- Filter(function(p) isTRUE(p$exists) && !is.na(p$card) && nz(p$stale_days, 0) > 7, projects)
  cat("Stale (> 7 days): ", length(st), "\n", sep = ""); for (p in st) cat("- ", p$name, ": ", p$stale_days, "d (", fmt_date(p$last_updated), ")\n", sep = "")
  ob <- Filter(function(p) any(grepl("over budget", p$problems)), projects)
  cat("\nOver size budget: ", length(ob), "\n", sep = ""); for (p in ob) cat("- ", p$name, ": ", paste(grep("over budget", p$problems, value = TRUE), collapse = "; "), "\n", sep = "")
  ni <- Filter(function(p) "NO-IMPORTANCE" %in% p$badges, projects)
  cat("\nMissing importance: ", length(ni), "\n", sep = ""); for (p in ni) cat("- ", p$name, "\n", sep = "")
  lg <- Filter(function(p) any(grepl("legacy card", p$problems)), projects)
  cat("\nLegacy (untagged) cards: ", length(lg), "\n", sep = ""); for (p in lg) cat("- ", p$name, "\n", sep = "")
  cat("\n")
}
if (MODE == "weekly") {
  act <- Filter(function(p) isTRUE(p$exists) && !is.na(p$card) && p$status == "active" && !isTRUE(p$excluded), projects)
  committed <- sum(vapply(act, function(p) nz(p$weekly_h, 0), 0))
  cat("## Weekly commitment\n- Committed (active cards, parsed weekly_commitment): ", round(committed, 1), "h / ", round(available, 1), "h available => ", if (committed > available) paste0("OVER by ", round(committed - available, 1), "h") else "fits", "\n\n", sep = "")
}

cw <- unlist(lapply(projects, function(p) if (length(p$cross_waits)) paste0(p$name, " ", p$cross_waits)))
if (MODE == "daily") cw <- clip(cw[!grepl("\\] - (none|n/a)\\.?$", cw, ignore.case = TRUE)], 210)
if (length(cw)) cat("## Cross-person waits (shared cards)\n", paste0("- ", cw, collapse = "\n"), "\n\n", sep = "")
if (length(changed)) cat("## Changed since you last looked\n", paste0("- ", changed, collapse = "\n"), "\n\n", sep = "")
cat("## Mail\nUnread addressed to ", ME, "/", AGENT, "/all: ", n_unread, " (of ", mail_total, " addressed to you)", if (n_unread && MODE != "mail") "  -- `/bob mail` to read" else "", "\n", sep = "")
if (MODE == "mail" || (n_unread && MODE == "weekly")) for (nm in names(mail_unread)) { cat("\n### ", nm, "\n", sep = ""); for (ln in rev(mail_unread[[nm]])) cat(if (MODE == "mail") ln else sub("^(- [^|]+\\| from: [^|]+\\| to: [^|]+\\| [^|]+)\\|.*$", "\\1", ln), "\n", sep = "") }
if (MODE == "mail" && STORE) cat("\n(marked as read in mail-seen.json)\n")
cat("\n")

if (MODE != "daily" || !is.null(upcoming) && nrow(upcoming)) {
  cat("## Calendar: next 90 days\n")
  if (!is.null(upcoming) && nrow(upcoming)) for (k in seq_len(nrow(upcoming))) cat("- ", fmt_date(upcoming$start[k]), if (upcoming$end[k] != upcoming$start[k]) paste0(" to ", fmt_date(upcoming$end[k])) else "", ": ", upcoming$text[k], "\n", sep = "") else cat("- none\n")
  cat("\n")
}
if (MODE %in% c("weekly", "monthly") && length(horizon)) cat("## Horizon notes\n", paste(horizon, collapse = "\n"), "\n\n", sep = "")
if (length(notes_pending)) cat("## Pending notes due\n", paste(notes_pending, collapse = "\n"), "\n\n", sep = "")
cat("## Idea backlog\n", n_ideas, " idea(s) in future-projects.md\n\n", sep = "")

probs <- unlist(lapply(projects, function(p) if (length(p$problems)) paste0(p$name, ": ", paste(p$problems, collapse = "; "))))
cat("## Data problems\n", if (length(probs)) paste0("- ", probs, collapse = "\n") else "- none", "\n\n", sep = "")
cat("Counts: ", sum(vapply(projects, function(p) isTRUE(p$exists) && !is.na(p$card), TRUE)), " cards read, ",
    sum(vapply(projects, function(p) "UNTRACKED" %in% p$badges, TRUE)), " untracked, ", sum(vapply(projects, function(p) "MISSING" %in% p$badges, TRUE)), " missing, ",
    sum(vapply(projects, function(p) nz(p$stale_days, 0) > 7, TRUE)), " stale > 7d, ", length(unlist(lapply(projects, `[[`, "conflicts"))), " conflict copies.\n", sep = "")
