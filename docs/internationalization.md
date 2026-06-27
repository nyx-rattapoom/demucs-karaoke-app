# Internationalization

The app uses a small catalog-based i18n setup for frontend UI text.

## Current Locales

- `en`: English fallback/source catalog
- `zh-CN`: Simplified Chinese UI catalog

Only frontend UI copy is translated. Song titles, artists, lyrics, media filenames, provider output,
and API payload content remain unchanged.

## Runtime Flow

- `services/i18n_service.py` resolves locale from `karaoke_locale`, then `Accept-Language`, then `en`.
- Templates call `t("key")`.
- Browser scripts call `window.KaraokeI18n.t("key", params)`.
- The header language selector posts to `POST /language`, which sets `karaoke_locale` and redirects
  back to the current app-local page.

## Add A Locale

1. **Register the locale** — add its code and native label to the `SUPPORTED_LOCALES` dict in
   `services/i18n_service.py` (keys are locale codes, values are native labels; `en` stays first as
   the `DEFAULT_LOCALE`):

   ```python
   SUPPORTED_LOCALES = {
       "en": "English",
       "zh-CN": "简体中文",
       "th": "ไทย",  # example: Thai
   }
   ```

2. **Add a normalizer alias** — in the `normalize_locale()` function of the same file, add a branch
   for any regional/underscore variants so they resolve to the base code.  Mirror the existing `zh`
   and `en` branches (the function works on a lower-cased, `_`→`-` normalized `lowered` string):

   ```python
   if lowered == "th" or lowered.startswith("th-"):
       return "th"
   ```

3. **Create the catalog** — add `locales/<code>.json` with **every key** that appears in
   `locales/en.json` (the master catalog).  Translate the human-readable text; preserve every
   `{placeholder}` token verbatim.  Key parity and placeholder parity are both enforced by the test
   suite, so any drift will fail CI.

4. **Verify the language selector** — open `templates/base.html` and confirm the language popover
   loops over `supported_locales()` rather than containing hardcoded per-locale buttons.  The
   collapsed selector label must derive a short display code from `locale.code` generically, e.g.:

   ```html
   {{ locale.code.split('-')[0]|upper }}
   ```

   If the template already does this, no change is needed; if it has hardcoded branches, replace them
   with the dynamic loop.

5. **Add a webfont if the script requires one** — if the locale uses a script not covered by the
   existing Latin fonts (Space Grotesk / Inter), wire in a font that covers it. Tailwind is loaded
   via the CDN with its config **inline** in `templates/base.html` (`<script id="tailwind-config">`),
   so there is no `tailwind.config.js` file. Two edits in `base.html`:

   a. Append the family to the existing Google Fonts `css2` link (one combined request — do not add a
      second `<link>`):

   ```html
   <!-- append &family=Noto+Sans+Thai:wght@300;400;500;600;700 before &display=swap -->
   ```

   b. Add the family to both `fontFamily` arrays in the inline `tailwind.config` block, before the
      `sans-serif` fallback:

   ```js
   fontFamily: {
       "headline": ["Space Grotesk", "Noto Sans Thai", "sans-serif"],
       "body": ["Inter", "Noto Sans Thai", "sans-serif"],
   }
   ```

   Ensure body text resolves to a Thai-capable family (the `body {}` rule in `base.html` sets
   `font-family` explicitly). Locales whose script is already covered (e.g. Latin-based) can skip
   this step.

6. **Routing is already locale-generic** — `build_docs_url` in `routes/pages.py` derives
   `/help/<slug>/` from the locale automatically.  No per-locale code change is needed there.
   Translated docs *content* under the docs-site is a separate concern outside this repo.

7. **Run the tests**:

   ```bash
   DEMUCS_ENV_FILE=/nonexistent .venv/bin/python -m pytest tests/routes/pages.py -q
   ```

   The suite includes:
   - A catalog key-parity check (every key in `en.json` must exist in every other catalog).
   - A placeholder-parity check (`{...}` tokens must match between `en.json` and each translation).
   - Page-render smoke tests for each locale in `SUPPORTED_LOCALES`.

   All three must be green before merging.
