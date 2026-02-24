# AGENTS.md

This file helps coding agents work effectively in this repository.

## Project Overview

- App name: `tekstitv`
- Type: Ruby terminal (Curses) app for browsing YLE Teletext pages.
- Primary runtime entrypoint: `./tekstitv`
- Alternate entrypoint: `bin/tekstitv`
- Source root: `lib/tekstitv`

## Setup Expectations

- Ruby standard library dependencies only (`curses`, `json`, `net/http`, `openssl`, `cgi`).
- Required env vars:
  - `YLE_APP_ID`
  - `YLE_APP_KEY`
- Local secrets load from `.env` (see `TekstiTV::Env.load!`).
- If SSL certificate issues appear, set `SSL_CERT_FILE`.

## Architecture

- `lib/tekstitv.rb`: namespace loader.
- `lib/tekstitv/app.rb`: main loop, navigation, history, refresh, page advancement logic.
- `lib/tekstitv/client.rb`: YLE API HTTP client + disk cache (`cache/*.json`) + in-memory cache.
- `lib/tekstitv/parser.rb`: converts teletext JSON payloads to plain text.
- `lib/tekstitv/ui.rb`: Curses rendering + key handling + layout/reflow/highlighting.
- `lib/tekstitv/env.rb`: `.env` loading and credential validation.

## Runtime Flow

1. `TekstiTV.run` boots `TekstiTV::App`.
2. Env is loaded and credentials validated.
3. App starts at page `100`.
4. UI renders content from cache first; API fetch occurs when needed (`allow_api: true`).
5. Navigation actions (`prev`, `next`, direct page, back, refresh, home) update page/history/cache.
6. Appendix links are derived from page 100 and shown on every page.

## Caching Behavior

- In-memory page cache: per process (`text_cache` hash).
- Disk cache: `cache/<page>.json`.
- Default render path prefers cache/disk and avoids API unless explicitly allowed.
- Refresh (`r`) invalidates memory + disk for current page and refetches.

## Input and Controls

- `q`: quit
- `ESC`: back in history
- `A` / left arrow: previous page
- `D` / right arrow: next page
- `h`: page 100
- `r`: refresh current page from API
- `NNN` + Enter: jump to page

## Agent Working Rules for This Repo

- Keep changes minimal and focused; avoid broad refactors.
- Preserve current terminal UX behavior unless explicitly requested.
- Do not remove cache behavior unless task requires it.
- Treat page content parsing as data-shape tolerant; YLE payloads can vary.
- Keep compatibility with 3-digit page navigation and existing keybindings.
- Prefer adding/adjusting small private methods over large structural changes.

## Validation Checklist After Changes

- Syntax check:
  - `ruby -c lib/tekstitv/app.rb`
  - `ruby -c lib/tekstitv/client.rb`
  - `ruby -c lib/tekstitv/parser.rb`
  - `ruby -c lib/tekstitv/ui.rb`
- Smoke run (interactive):
  - `./tekstitv`
- Verify key paths manually:
  - initial page render
  - direct page jump
  - prev/next navigation
  - refresh behavior
  - back history

## Notes

- Repository may be dirty during work; do not revert unrelated user edits.
- `cache/` content is runtime data and can be noisy in diffs.
