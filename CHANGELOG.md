# Changelog

All notable changes to the Huawei-doc-templates project are documented here.
Per-document changelogs are maintained via `\changelogentry` in each `.tex` file.

## v2.0.0 (2026-08-19)

### Major: Class decomposition + multi-format output

- **Phase 1**: Decomposed `guide.cls` (600 lines) into 10 shared `.sty` modules
  under `templates/_base/` (colors, fonts, lang, page, tables, code, callouts,
  images, changelog, shared). `guide.cls` reduced to ~194 lines.
- **Phase 2**: Added multi-format output via Pandoc + Lua filter. Generates
  DOCX, Markdown, HTML, and EPUB from LaTeX source. The Lua filter translates
  all custom commands (`\makecover`, `\infobox`, `\objective`, `\stepbystep`,
  `\image`, `\note`, `\hutable`, `\codefile`, `\badge`, `\menu`, `\changelog`,
  etc.) to Pandoc AST elements.
- Added `build.sh` interactive format selection menu with `--pdf`, `--docx`,
  `--md`, `--html`, `--epub`, `--all`, `--dry-run` flags.
- Added `make menu` Makefile target delegating to `build.sh`.
- Added reference DOCX (`guide-reference.docx`) with custom Huawei styles.
- Added HTML template (`guide-template.html`) with Huawei brand CSS.
- Added EPUB output support.
- Added Lua filter unit tests (`tests/` with 14 test cases).
- Added `.luacheckrc` for static analysis.
- Added ARIA roles on callout divs in HTML output.
- Added `lang` attribute on HTML `<html>` element from documentclass option.
- Added `pdftitle`/`pdfauthor` PDF metadata via `\hypersetup`.
- Added module dependency comments in all `.sty` files.
- Added `PANDOC_VERSION:must_be_at_least('3.0')` runtime version gating.
- Added `os.setlocale('C')` for consistent pattern matching.
- Added `log_warn()` helper for stderr error reporting in Lua filter.
- Added font fallback warning surfacing in `build.sh`.
- Added log excerpt display on compilation failure in `build.sh`.
- Added "what this will do" summary in `install.sh` before confirmation.
- Fixed `\imageplaceholder` producing broken `<img>` in DOCX/HTML.
- Fixed image alt text: empty alt for uncaptioned images (WCAG 2.1).
- Fixed `\note` prefix inconsistency between preprocess and RawInline.
- Simplified Lua filter: dispatch table, extracted helpers (split_row,
  parse_image, parse_codefile, is_strip_cmd), callout factory.
- Simplified build system: Makefile delegates to build.sh, collapsed
  generate functions.
- Simplified .sty modules: deleted no-op `\two@digits`, moved `\thd`/`\tbody`
  to huawei-tables.sty, inlined `\lg@label`.
- Trimmed AGENTS.md: moved L2/L3/L7/L10 from locked decisions to conventions.

## v1.7.0 (2026-08-17)

- Added "Limpeza" chapter to Portuguese sample for pt/en parity.
- Fixed `\codefile` with `\IfFileExists` guard.
- Removed dead imports from samples.
- Fixed `install.sh` PDF preservation.

## v1.6.0 (2026-08-12)

- `changelog` environment now emits its own section heading.
- `[nochangelog]` suppresses the heading and entries in one switch.

## v1.5.0 (2026-08-12)

- New `hutable` environment: full-grid tables with Huawei-red header and
  alternating body rows.
- Floats now default to `[H]` placement (in-source order).

## v1.4.0 (2026-08-10)

- Default image size increased: width 65% → 90%, height 40% → 50%.
- H1 section title size adjusted (18pt → 20pt).

## v1.3.0 (2026-08-10)

- `nochangelog` option now hides version, date, and time on cover page.
- Document date defaults to `\today` (compilation date).

## v1.2.0 (2026-08-09)

- Added key-value sizing options to `\image` and `\imagecap`.
- Fixed PDF copy-paste of URLs in code blocks (disabled Cascadia Code ligatures).
- Fixed italic font rendering (AutoFakeSlant for fonts without italic variants).

## v1.1.0 (2026-08-08)

- Added Huawei-branded table styling: red header bar, alternating row colors.
- Changed table and figure caption labels to black (was Huawei red).

## v1.0.0 (2026-08-05)

- Initial version.
- Added callout boxes, badge, and changelog support.
- Huawei Cloud guide template with branded cover, header, TOC, giant chapter
  numbers, objectives block, code blocks, tables, and images.
- English (default) and Portuguese language support.
