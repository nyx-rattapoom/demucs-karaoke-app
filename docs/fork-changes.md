# Fork Changes

What this fork adds to and changes from upstream, and how to reproduce the exact delta.

## About this fork

- **Upstream:** [`vttc08/demucs-karaoke-app`](https://github.com/vttc08/demucs-karaoke-app) — the project this repository is forked from.
- **This fork (origin):** `nyx-rattapoom/demucs-karaoke-app`.
- The fork's `main` tracks upstream: `origin/main` and `upstream/main` are identical. Fork-specific work lives on the **`internal-use`** branch, which is what this document describes.

## Why this fork exists / relationship to upstream

This fork carries a set of internal-use features and fixes layered on top of upstream `main` (see [Fork changes](#fork-changes) below). Upstream is followed by keeping `main` in sync; the fork's additions are integrated on `internal-use`.

**Merge-back intent:** these changes are proposed for upstream — a merge request is open against [`vttc08/demucs-karaoke-app`](https://github.com/vttc08/demucs-karaoke-app) but has not been accepted yet. Until it is, `internal-use` remains the fork's feature layer and is periodically rebased onto the latest upstream `main`.

## How the delta is defined

The fork delta is every commit on `internal-use` that is not on upstream `main`. It is defined against the merge-base so it stays stable as upstream advances:

```bash
# Prerequisite: the upstream remote must exist. A fresh clone of the fork
# (origin) does not have it — add it once:
git remote add upstream https://github.com/vttc08/demucs-karaoke-app

# The delta (pinned to the merge-base, not a moving branch tip):
git diff --stat "$(git merge-base upstream/main internal-use)..internal-use"
git log  --no-merges "$(git merge-base upstream/main internal-use)..internal-use"
```

Since `origin/main == upstream/main`, `git merge-base origin/main internal-use` is an equivalent fallback if you have not added the `upstream` remote.

**The command output above is authoritative. The numbers below are a dated snapshot** and will drift as either branch moves — regenerate them with the commands above.

### Snapshot (as of 2026-07-13)

- `internal-use` at `8c81bbc`, merge-base with upstream at `67ec4c5`.
- **11 commits**, **22 files changed**, **+1193 / −53**.

## Fork changes

Five feature groups. Each maps to real commits in the range above.

### 1. Tunable Demucs separation params

**What:** Exposes Demucs quality/performance knobs end to end — `segment`, `shifts`, `jobs`, `overlap` — configurable via `DEMUCS_*` environment variables.

**Why:** Lets deployments trade separation quality against speed and memory without code changes (e.g. on CPU, a smaller `segment` plus modest `overlap` balances RAM and runtime).

**How it threads through:** `.env` (`DEMUCS_SEGMENT`, `DEMUCS_SHIFTS`, `DEMUCS_JOBS`, `DEMUCS_OVERLAP`) → app `config.py` and `demucs_svc/settings.py` → validated on `SeparateConfig` (`demucs_svc/models.py`) → carried on `SeparationRequest` (`demucs_svc/separation/base.py`) → emitted as CLI flags by `build_command` (`demucs_svc/separation/demucs.py`) → accepted as form fields on the `demucs_svc` job endpoints (`demucs_svc/app.py`) and forwarded by `services/demucs_client.py`. Defaults are `None`, so Demucs' built-in defaults apply unless a knob is explicitly set. `segment` is an **`int`** (the Demucs CLI `--segment` flag rejects floats).

**Key files:** `.env.example`, `config.py`, `demucs_svc/settings.py`, `demucs_svc/models.py`, `demucs_svc/separation/base.py`, `demucs_svc/separation/demucs.py`, `demucs_svc/app.py`, `demucs_svc/demucs_runner.py`, `services/demucs_client.py`, `tests/test_demucs_svc.py`.

See also [`separation-backends.md`](separation-backends.md) for the surrounding separation-provider architecture.

### 2. Thai (th) UI locale

**What:** Adds Thai as a first-class frontend locale alongside English and Simplified Chinese.

**Why:** Thai-speaking users get a fully localized UI.

**How:** `services/i18n_service.py` registers `"th": "ไทย"` in `SUPPORTED_LOCALES` and adds a `normalize_locale` alias branch so `th` / `th-TH` resolve to `th`. `locales/th.json` is a complete catalog whose key set and `{placeholder}` tokens match `en.json`. `templates/base.html` generalizes the language selector — the popover and collapsed label now iterate over `supported_locales()` instead of two hardcoded entries — and adds the Noto Sans Thai webfont with font-family fallbacks.

**Key files:** `services/i18n_service.py`, `locales/th.json`, `templates/base.html`, `docs/internationalization.md`, `tests/routes/pages.py`.

See also [`internationalization.md`](internationalization.md) for the add-a-locale guide.

### 3. `run_all.sh` dev tooling

**What:** A single script that launches both services together — the Demucs separation API (`demucs_svc.app:app`, port 8001) and the web app (`main:app`, port 8000) — with prefixed log streams and a `trap` that stops both on Ctrl-C.

**Why:** Local development needs both processes; one command avoids juggling two terminals. Hosts/ports are overridable via `WEB_HOST`/`WEB_PORT`/`DEMUCS_HOST`/`DEMUCS_PORT`.

**Key files:** `run_all.sh`.

### 4. QR code improvements

**What / Why:** Three related fixes to the `/api/qr` stage code:

- **Standard QR, not Micro QR.** Switched from `segno.make()` to `segno.make_qr()`. `segno.make()` auto-downgrades short payloads (e.g. `127.0.0.1`, `localhost`) to a Micro QR, which has a single finder pattern and is unscannable by most phone cameras. Sends `Cache-Control: no-cache` so a regenerated code is not served stale from the browser cache.
- **Memoized rendering.** Extracted a pure `_render_qr_png(data, size) -> bytes` helper memoized with `@lru_cache`; the route wraps a fresh `BytesIO` over the cached immutable bytes per request. Identical concurrent requests are served instantly and safely. The cache is process-local, so a deploy that changes rendering starts cold and never serves a stale render.
- **Full stage URL with port.** When no Stage QR URL is configured, the fallback now derives an absolute URL from the current page (`window.location.origin` + the queue path via `appUrl`, preserving `KARAOKE_BASE_PATH`) instead of the bare `window.location.hostname`, which dropped the scheme and port.

**Key files:** `routes/qr.py`, `templates/stage.html`, `tests/routes/qr.py`, `tests/test_routes.py`.

### 5. Decoupled WhisperX align toggle

**What:** In the Configure Queue modal, word alignment no longer auto-enables when lyrics or karaoke are turned on. The align toggle stays off until the user explicitly opts in.

**Why:** Alignment is an expensive, optional step; auto-enabling it surprised users and ran WhisperX when it was not wanted.

**How:** Removed the three auto-enable points (modal open, karaoke-on, lyrics-on) in `static/queue.js` while keeping all force-off safety guards (alignment is still forced off when karaoke or lyrics are off, since it cannot run without them).

**Key files:** `static/queue.js`.

## Files not tied to a user-facing feature

Some paths in the delta are supporting changes rather than their own feature:

- `config.py`, `demucs_svc/settings.py` — plumbing for the [Tunable Demucs params](#1-tunable-demucs-separation-params) group (the env/settings wiring behind those knobs).
- `.gitignore` — repo housekeeping.
- `tests/routes/pages.py`, `tests/routes/qr.py`, `tests/test_demucs_svc.py`, `tests/test_routes.py` — tests covering the groups above.

## Keeping this doc in sync

This document is a point-in-time snapshot on a live branch. When `internal-use` or upstream moves:

1. Re-run the commands in [How the delta is defined](#how-the-delta-is-defined) to regenerate the commit list and the `--stat` totals.
2. Update the [Snapshot](#snapshot-as-of-2026-07-13) block (date, `internal-use` SHA, merge-base SHA, counts).
3. If a new feature group landed, add a `###` section for it; if a commit only touches supporting files, list it under [Files not tied to a user-facing feature](#files-not-tied-to-a-user-facing-feature).

To confirm coverage, every path from
`git diff --name-only "$(git merge-base upstream/main internal-use)..internal-use"`
should map to a feature group above or to the supporting-files list.
