#!/usr/bin/env python3
"""Convert a Nota narrated-comic EPUB+MediaOverlay source folder into a DiViNa folder.

The Nota comic format (see docs/nota-comics/xhtml-structure.md) fakes a comic
experience on top of the Readium *EPUB* profile: each reading-order entry is an
XHTML page wrapping one full-page `<img class="page">` plus `<div class="area">`
panel regions, and a `syncnarr+json` media overlay maps panel/heading element
ids to audio time fragments.

Readium's *DiViNa* profile + Guided Navigation models exactly the same thing
natively: the reading order is the images themselves, and a single
`guided-navigation.json` document carries `imgref` (with `#xywh=` panel regions) and
`audioref` (with `#t=` time fragments) per narrated segment.

This script performs that mechanical transform:

  * reading order  <- the page images (a page with no `img.page`, e.g. a
    title-only page, falls back to the publication cover image)
  * guided nav     <- per page a `{role:[section], children:[...]}` entry; each
    child mirrors one syncnarr segment as:
        - audioref: the segment's audio (mp3 + #t= time range), verbatim
        - imgref:   the page image, plus `#xywh=pixel:left,top,w,h` when the
          segment's element id matches a `div.area` panel (whole image otherwise)

NOTE on `imgref`/panels: the audio-narration path ignores `imgref` entirely
(it only consumes audioref+textref). The xywh geometry is emitted purely so the
asset is complete for the future "narrated panel-zoom on DiViNa" work. Panel
coordinates are kept in the *authored* canvas space (the px values from the
source XHTML), which for one page (image0003) differs slightly from the image's
intrinsic height -- harmless until zoom rendering is implemented.

Usage (run from the repo root):
  bin/make_comic_divina.py <src-folder> <out-folder>

Example:
  bin/make_comic_divina.py \\
    Resources/webpub/epub+audio/50272-nota-comics \\
    Resources/webpub/divina/50272-nota-comics
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

DIVINA_PROFILE = "https://readium.org/webpub-manifest/profiles/divina"
GUIDED_NAV_TYPE = "application/guided-navigation+json"
GUIDED_NAV_NAME = "guided-navigation.json"

IMG_RE = re.compile(r"<img\b[^>]*>", re.IGNORECASE | re.DOTALL)
DIV_AREA_RE = re.compile(r'<div\b[^>]*class="area"[^>]*>', re.IGNORECASE | re.DOTALL)
ATTR_RE = lambda name: re.compile(rf'{name}\s*=\s*"([^"]*)"', re.IGNORECASE)
STYLE_PX_RE = lambda prop: re.compile(rf'{prop}\s*:\s*(\d+)px', re.IGNORECASE)


def _attr(tag: str, name: str) -> str | None:
    m = ATTR_RE(name).search(tag)
    return m.group(1) if m else None


def _style_px(tag: str, prop: str) -> int | None:
    style = _attr(tag, "style") or ""
    m = STYLE_PX_RE(prop).search(style)
    return int(m.group(1)) if m else None


def jpeg_size(data: bytes) -> tuple[int, int]:
    """Return (width, height) of a JPEG from its SOF marker (no PIL dependency)."""
    i = 2  # skip SOI
    n = len(data)
    while i + 9 < n:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        # SOF0..SOF15 except DHT(C4)/JPG(C8)/DAC(CC) carry frame dims.
        if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
            h = (data[i + 5] << 8) | data[i + 6]
            w = (data[i + 7] << 8) | data[i + 8]
            return w, h
        seg_len = (data[i + 2] << 8) | data[i + 3]
        i += 2 + seg_len
    raise ValueError("Could not parse JPEG dimensions")


def flatten_syncnarr(node: dict) -> list[tuple[str | None, str]]:
    """Flatten a syncnarr document to ordered (elementId, audioref) leaves."""
    out: list[tuple[str | None, str]] = []

    def walk(n):
        if isinstance(n, dict):
            text, audio = n.get("text"), n.get("audio")
            if isinstance(audio, str) and isinstance(text, str):
                frag = text.split("#", 1)[1] if "#" in text else None
                out.append((frag, audio))
            for child in n.get("narration", []) or []:
                walk(child)
        elif isinstance(n, list):
            for child in n:
                walk(child)

    walk(node)
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    src_path, out_path = Path(sys.argv[1]), Path(sys.argv[2])

    manifest = json.loads((src_path / "manifest.json").read_bytes())

    cover_href = next(
        (r["href"] for r in manifest.get("resources", []) if "cover" in (r.get("rel") or [])),
        "cover.jpg",
    )

    reading_order: list[dict] = []
    guided: list[dict] = []
    copy_files: set[str] = set()

    for entry in manifest["readingOrder"]:
        xhtml_href = entry["href"]
        title = entry.get("title", "")
        duration = entry.get("duration")
        mo_href = (entry.get("properties") or {}).get("media-overlay")

        xhtml = (src_path / xhtml_href).read_text(encoding="utf-8")

        # Locate the full-page image and panel regions.
        img_src, areas = None, {}
        for tag in IMG_RE.findall(xhtml):
            if "page" in (_attr(tag, "class") or ""):
                img_src = _attr(tag, "src")
                break
        for tag in DIV_AREA_RE.findall(xhtml):
            aid = _attr(tag, "id")
            if not aid:
                continue
            areas[aid] = (
                _style_px(tag, "left") or 0,
                _style_px(tag, "top") or 0,
                _style_px(tag, "width") or 0,
                _style_px(tag, "height") or 0,
            )

        image_href = img_src or cover_href  # title-only page -> cover
        copy_files.add(image_href)

        w, h = jpeg_size((src_path / image_href).read_bytes())
        ro_entry = {"href": image_href, "type": "image/jpeg", "title": title, "width": w, "height": h}
        if duration is not None:
            ro_entry["duration"] = duration
        reading_order.append(ro_entry)

        # Build the guided-navigation section from the syncnarr segments.
        # The syncnarr document is consumed to build the guided-navigation doc
        # but is NOT bundled into the DiViNa -- guided-navigation.json replaces it.
        children = []
        if mo_href and (src_path / mo_href).exists():
            segments = flatten_syncnarr(json.loads((src_path / mo_href).read_bytes()))
            for frag, audioref in segments:
                audio_file = audioref.split("#", 1)[0]
                copy_files.add(audio_file)
                if frag in areas:
                    left, top, aw, ah = areas[frag]
                    imgref = f"{image_href}#xywh=pixel:{left},{top},{aw},{ah}"
                else:
                    imgref = image_href
                children.append({"imgref": imgref, "audioref": audioref})
        guided.append({"role": ["section"], "children": children})

    # ToC: remap source toc titles onto the image reading order, in order.
    toc = [
        {"href": ro["href"], "title": ro.get("title", "")}
        for ro in reading_order
    ]

    md_src = manifest.get("metadata", {})
    metadata = {
        "conformsTo": DIVINA_PROFILE,
        "identifier": md_src.get("identifier"),
        "title": md_src.get("title"),
        "language": md_src.get("language"),
        "layout": "fixed",
        "@type": md_src.get("@type", "http://schema.org/Book"),
    }
    if md_src.get("modified"):
        metadata["modified"] = md_src["modified"]
    if md_src.get("duration") is not None:
        metadata["duration"] = md_src["duration"]
    metadata = {k: v for k, v in metadata.items() if v is not None}

    resources = [
        {"href": GUIDED_NAV_NAME, "type": GUIDED_NAV_TYPE},
        {"href": cover_href, "rel": ["cover"], "type": "image/jpeg"},
    ]
    for f in sorted(copy_files):
        if f.endswith(".mp3"):
            resources.append({"href": f, "type": "audio/mpeg"})

    out_manifest = {
        "@context": manifest.get("@context", "https://readium.org/webpub-manifest/context.jsonld"),
        "metadata": metadata,
        "links": [
            {"href": "manifest.json", "rel": "self", "type": "application/divina+json"},
            {"href": GUIDED_NAV_NAME, "type": GUIDED_NAV_TYPE},
        ],
        "readingOrder": reading_order,
        "resources": resources,
        "toc": toc,
    }
    guided_doc = {"guided": guided}

    copy_files.add(cover_href)

    out_path.mkdir(parents=True, exist_ok=True)
    (out_path / "manifest.json").write_text(json.dumps(out_manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    (out_path / GUIDED_NAV_NAME).write_text(json.dumps(guided_doc, ensure_ascii=False, indent=1), encoding="utf-8")
    for f in sorted(copy_files):
        dest = out_path / f
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((src_path / f).read_bytes())

    total_children = sum(len(s["children"]) for s in guided)
    print(
        f"Wrote {out_path}\n"
        f"  reading order: {len(reading_order)} images\n"
        f"  guided sections: {len(guided)} ({total_children} narrated segments)\n"
        f"  bundled files: {len(copy_files)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
