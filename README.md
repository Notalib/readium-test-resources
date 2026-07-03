# Test publications for Flutter Readium

This repository contains test publications in various formats for the [flutter_readium](https://github.com/Notalib/flutter_readium/).

These test publications should be in the public domain or otherwise free of copyright.
Some ones prefixed with a number are self-produced by Nota.

## Building the Publications

The source fixtures live under `Resources/` and the packaged outputs are built on demand.
Use `bin/build_publications.sh list` to see the current inventory instead of relying on a static table in this README.

```sh
bin/build_publications.sh list
bin/build_publications.sh build dist
bin/build_publications.sh build dist epub/moby_dick
bin/build_publications.sh build dist webpub/epub/712199_ebook
```

The build script applies these rules:

- `Resources/pdf/*.pdf` is copied unchanged.
- `Resources/epub/*` is packaged as `<name>.epub` with `mimetype` first and uncompressed.
- `Resources/webpub/epub/*` and `Resources/webpub/epub+audio/*` are packaged as `<name>.webpub`.
- `Resources/webpub/audiobook/*` is packaged as `<name>.audiobook`.
- `Resources/webpub/audiobook+remote/*` must contain only `manifest.json`. The build emits `<name>.json` from that manifest.

Publication ids are source-relative so they stay unique across formats, for example `pdf/alice`, `epub/moby_dick`, `webpub/epub/712199_ebook`, and `webpub/audiobook+remote/39031_auth`.

## Regenerating the PDFs

`time_machine.pdf` and `alice.pdf` are rendered from Project Gutenberg HTML via
headless Chrome / Chromium.

Use the cross-platform helper script:

```sh
bin/regenerate_pdfs.sh
```

By default it writes to `Resources/pdf/` and regenerates the two known fixtures:
`time_machine.pdf` and `alice.pdf`.

Useful options:

```sh
# Generate only one known fixture
bin/regenerate_pdfs.sh --preset alice

# Generate one or more known fixtures
bin/regenerate_pdfs.sh --preset time_machine --preset alice

# Generate from any gutenberg.org URL
bin/regenerate_pdfs.sh \
	--url "https://www.gutenberg.org/cache/epub/84/pg84-images.html" \
	--output frankenstein.pdf

bin/regenerate_pdfs.sh --output-dir Resources/pdf
bin/regenerate_pdfs.sh --chrome "/custom/path/to/chrome"
CHROME_BIN="/custom/path/to/chrome" bin/regenerate_pdfs.sh
bin/regenerate_pdfs.sh --dry-run
```

The script supports macOS, Linux, and Windows shell environments (for example
Git Bash or WSL on Windows). If auto-detection fails, pass `--chrome` or
`CHROME_BIN`.

Gutenberg no longer offers PDF as a native download format, hence the HTML →
Chrome round-trip. The result is a real text-based PDF (selectable text,
embedded fonts) suitable for exercising `PDFPositionsService` and the PDFium
adapter.
