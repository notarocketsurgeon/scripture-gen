# Passage of the Day — State

## What this is

A configurable, sandboxed CLI tool that outputs a **passage of the day** from the KJV Bible (or other texts via config). Written in Dart. Created June 12, 2026.

## Architecture

### Project layout

```
passage-of-the-day/
├── bin/passage.dart           # CLI entry point, arg parsing, main flow
├── lib/
│   ├── bible.dart             # Book names/aliases, reference parsing, Bible class
│   ├── config.dart            # Sandbox discovery, config loading, init
│   ├── download.dart          # HTTP download of KJV JSON (2 fallback URLs)
│   ├── format.dart            # Output formatting (text, simple, json)
│   └── selector.dart          # Selection algorithm, curated cycling
├── passages/default/          # Default sandbox (version-controlled)
│   ├── config.json
│   ├── curated.txt
│   └── kjv.json               # Downloaded on first run (gitignored)
├── pubspec.yaml               # name: passage_of_the_day, sdk >=3.0
├── passage                    # Shell wrapper (./passage)
└── STATE.md                   # This file
```

### Key design points

- **Sandboxed**: Each `passages/<name>/` is fully self-contained — its own `config.json`, `curated.txt`, and cached `kjv.json`. Swap via `-s <name>` or `PASSAGE_SANDBOX` env var.
- **Dual selection**: Configurable `curated_weight` (default 0.3). Remainder picks random from full Bible.
  - **Curated**: Featured (`!`) entries first, then shuffled normals, persisted in `.curated_state.json` (order + cursor). Wraps around when exhausted.
  - **Random**: Weighted toward popular books (Psalms 5x, John 4x, Proverbs 4x, etc.). Geometric distribution for passage length (avg ~2, max configurable via `max_verses`).
- **KJV download**: First run fetches JSON from GitHub (list-of-books format: `{name, abbrev, chapters[][]}`). Cached per-sandbox. Falls back to curated-only if download fails.
- **Reference parsing**: Supports `Book C:V`, `Book C:V-V`, `Book C`. 66-book alias table (e.g., `Ps`, `1cor`, `jn`). Normalizes book names from JSON source.
- **Three output formats**: `text` (boxed with date), `simple` (ref + text), `json`.

### Dependencies

None external. Uses only `dart:io`, `dart:convert`, `dart:math`.

### CLI usage

```
./passage                          # Random verse of the day (text)
./passage -r "John 3:16"           # Look up specific reference
./passage -f json                  # JSON output
./passage -f simple                # Plain text
./passage -n 3                     # Multiple passages
./passage --init -s my-theme       # Scaffold a new sandbox
./passage -s my-theme              # Run with that sandbox
./passage --list-curated           # List curated pool
./passage --no-download            # Curated-only (no KJV fetch)
```

## Current state (what works)

- [x] KJV downloads and caches on first run
- [x] Random verse selection with weighted books and variable length
- [x] Curated pool with featured/normal, shuffle-and-cycle, state persistence
- [x] Book alias normalization for ~60+ abbreviations
- [x] Sandbox init, listing, switching
- [x] Reference lookup (`-r`)
- [x] Three output formats (text, simple, json)
- [x] `--count` for multiple passages
- [x] `--no-download` for offline curated mode
- [x] Shell wrapper (`./passage`)
- [x] **Comprehensive curated list**: 705 curated passages across 20+ thematic categories (Salvation, Creation, Jesus, Grace, Wisdom, Comfort, Prayer, Worship, Psalms, Proverbs, Sermon on the Mount, Love, Strength, Repentance, Word of God, Holy Spirit, Spiritual Warfare, Hope, Mission, Family, Work, Trials, Memory Verses, Christmas, Cross/Resurrection, Daily Rotation)

## Known gaps / next steps

- **Data sources**: Only KJV JSON from GitHub. No explicit interface for other translations or texts.
- **Config surface**: No `theme`, `book_weights`, `output_width`, `date_format`, or per-sandbox overrides. `config.json` currently just has `bible`, `curated_weight`, `max_verses`.
- **No date anchoring**: "Verse of the day" is random each run, not date-seeded. Seeding by date would give the same verse all day.
- **No web UI**: CLI only. No HTTP server or web frontend.
- **No testing**: No test files yet.
- **No CI/packaging**: No GitHub Actions, no published package.
- **Ref edge cases**: Multi-chapter references (e.g., `Gen 1:1–2:3`) not supported in parser.
- **Formatting**: Curly brace textual notes (e.g., `{or: wicked}`) from KJV source are passed through verbatim. No clean-up.
- **Seasonal awareness**: No way to anchor to liturgical calendar (Advent, Lent, Easter) or special occasions. Thematic categories exist but aren't date-weighted.

## Running

```bash
# (ensure dart is in PATH)
dart pub get
./passage
```
