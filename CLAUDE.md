# CLAUDE Instructions for readium-test-resources

## Purpose

This repository contains publication fixtures used by flutter_readium for integration and behavior testing.
It is not an application runtime repository.

Favor changes that keep fixtures deterministic, easy to rebuild, and representative of real publication formats.

## Repository Layout

- `Resources/pdf/`: Source PDF fixtures copied as-is into build outputs.
- `Resources/epub/`: Source EPUB directories.
- `Resources/webpub/epub/`: WebPub fixtures built from EPUB-style source directories.
- `Resources/webpub/epub+audio/`: WebPub fixtures that include audio resources.
- `Resources/webpub/audiobook/`: Audiobook fixtures packaged from source directories.
- `Resources/webpub/audiobook+remote/`: Remote audiobook manifests. Each fixture directory contains only `manifest.json`; the build emits `<name>.json`. All remote-manifest fixtures live under a `*+remote` folder by convention.
- `Resources/webpub/divina/`: DiViNa fixtures (folder, packaged as `.divina` by build script). Generated from `epub+audio` sources via `bin/make_comic_divina.py`.
- `Resources/cbz/`: Comic Book ZIP source directories (packaged as `.cbz`).
- `Resources/downloaded/`: **Gitignored.** Pre-built archives downloaded by `bin/download_sample_fixtures.py`. Not committed; populate locally after cloning.
- `bin/build_publications.sh`: Source of truth for inventory and packaging behavior.

## Build and Validation Commands

Use the build script instead of ad-hoc zip/copy commands.

```sh
bin/build_publications.sh list
bin/build_publications.sh build dist
bin/build_publications.sh build dist epub/moby_dick
bin/build_publications.sh build dist webpub/epub/712199_ebook
```

Notes:
- Publication IDs are source-relative, for example `pdf/alice`, `epub/moby_dick`, `webpub/audiobook/38533`.
- `zip` must be installed for archive outputs.
- CI validates that the number of built files matches the inventory from `list`.

## Fixture Rules

When adding or changing fixtures, keep these invariants intact:

- PDF: `Resources/pdf/*.pdf` is copied unchanged.
- EPUB: each `Resources/epub/<name>/` directory is packaged as `<name>.epub`.
  - `mimetype` must exist in the fixture root.
  - `mimetype` is packaged first and uncompressed.
- WebPub EPUB and EPUB+Audio:
  - `Resources/webpub/epub/<name>/` and `Resources/webpub/epub+audio/<name>/` are packaged as `<name>.webpub`.
- Audiobook:
  - `Resources/webpub/audiobook/<name>/` is packaged as `<name>.audiobook`.
- Remote audiobook:
  - `Resources/webpub/audiobook+remote/<name>/` must contain only `manifest.json`.
  - The build emits `<name>.json` from `manifest.json`.

## Contributor Workflow

1. Add or update fixture files under the correct `Resources/` subtree.
2. Confirm discovery:
   ```sh
   bin/build_publications.sh list
   ```
3. Build and smoke-test locally:
   ```sh
   target_dir="$(mktemp -d)"
   bin/build_publications.sh build "$target_dir"
   ```
4. For focused iteration, build one publication ID:
   ```sh
   bin/build_publications.sh build "$target_dir" webpub/epub/712199_ebook
   ```

## Common Failures and Fixes

- `Required tool not found: zip`
  - Install `zip` and rerun.
- `Unknown publication id: ...`
  - Use `bin/build_publications.sh list` and copy an exact ID.
- `Missing mimetype in ...`
  - Ensure EPUB fixture root contains `mimetype`.
- `Missing manifest.json` in `audiobook+remote`
  - Ensure the fixture directory contains `manifest.json` at its root.

## Governance

- Add only fixtures that are public domain or otherwise copyright-clear.
- Do not commit secrets (tokens, keys, credentials) to fixture files or manifests.
- Keep manifests and metadata realistic for testing, but sanitize any private or sensitive data.

## Scope Boundaries

When working in this repository:
- Prefer fixture and packaging updates only.
- Avoid introducing unrelated tooling, frameworks, or broad refactors.
- Keep README and this file aligned when command behavior changes.
