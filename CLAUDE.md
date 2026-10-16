# CLAUDE Instructions for readium-test-resources

Publication fixtures for flutter_readium integration tests. Not an app runtime.
Keep fixtures deterministic, easy to rebuild, and representative of real publication formats.
Fixture and packaging changes only. No new tooling, frameworks or broad refactors.

## Layout

- `Resources/pdf/` — PDFs, copied unchanged.
- `Resources/epub/<name>/` — packaged as `<name>.epub`. Needs `mimetype` in the fixture root; it is packaged first and uncompressed.
- `Resources/webpub/epub/<name>/` and `Resources/webpub/epub+audio/<name>/` — packaged as `<name>.webpub`.
- `Resources/webpub/audiobook/<name>/` — packaged as `<name>.audiobook`.
- `Resources/webpub/audiobook+remote/<name>/` — must contain only `manifest.json`; build emits `<name>.json`. All remote-manifest fixtures live under a `*+remote` folder.
- `Resources/webpub/divina/` — packaged as `.divina`. Generated from `epub+audio` sources via `bin/divina_from_nota_comic.py`.
- `Resources/cbz/<name>/` — packaged as `<name>.cbz`.
- `Resources/generated/` — gitignored, built locally by `bin/cbz_gen_sample.py`.
- `bin/build_publications.sh` — source of truth for inventory and packaging.

## Commands

Use the build script, not ad-hoc zip/copy. `zip` must be installed.

```sh
bin/build_publications.sh list
bin/build_publications.sh build dist
bin/build_publications.sh build dist webpub/epub/712199_ebook   # one id
```

Publication IDs are source-relative: `pdf/alice`, `epub/moby_dick`, `webpub/audiobook/38533`.
For the contributor workflow, follow the checklist in `README.md`. CI checks that the built file count matches `list`.

## Failures

- `Required tool not found: zip` — install `zip`.
- `Unknown publication id` — copy an exact ID from `list`.
- `Missing mimetype in ...` — add `mimetype` to the EPUB fixture root.
- `Missing manifest.json` — add it to the `audiobook+remote` fixture root.

## Governance

- Public-domain or copyright-clear fixtures only.
- No secrets in fixture files or manifests. Sanitize private data.
- Keep README and this file aligned when command behavior changes.
