#!/usr/bin/env python3
"""Validate or fix a manifest-only fixture's remote resource references.

Manifest-only fixtures are copied without packaging their referenced resources.
That is only valid when every non-self href points to an absolute remote URL.
"""

import argparse
import json
import sys
from urllib.parse import urljoin, urlparse


def iter_hrefs(value):
    if isinstance(value, dict):
        href = value.get("href")
        if isinstance(href, str) and href:
            yield href
        for child in value.values():
            yield from iter_hrefs(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_hrefs(child)


def fix_hrefs(value, base_url):
    if isinstance(value, dict):
        href = value.get("href")
        if isinstance(href, str) and href and not is_absolute(href) and not is_self_manifest(href):
            value["href"] = urljoin(base_url, href)
        for child in value.values():
            fix_hrefs(child, base_url)
    elif isinstance(value, list):
        for child in value:
            fix_hrefs(child, base_url)


def is_self_manifest(href):
    parsed = urlparse(href)
    return not parsed.scheme and not parsed.netloc and parsed.path == "manifest.json"


def is_absolute(href):
    parsed = urlparse(href)
    return bool(parsed.scheme)


def link_rels(link):
    rel = link.get("rel")
    if isinstance(rel, str):
        return {rel}
    if isinstance(rel, list):
        return {item for item in rel if isinstance(item, str)}
    return set()


def manifest_self_href(manifest):
    for link in manifest.get("links", []):
        if not isinstance(link, dict):
            continue
        href = link.get("href")
        if isinstance(href, str) and "self" in link_rels(link) and is_absolute(href):
            return href
    return None


def relative_hrefs(manifest):
    return [
        href
        for href in iter_hrefs(manifest)
        if not is_absolute(href) and not is_self_manifest(href)
    ]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Validate or fix a manifest-only fixture's remote resource hrefs."
    )
    parser.add_argument("manifest", help="Path to the manifest.json to validate")
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Print a fixed manifest with non-self relative hrefs rewritten to absolute URLs",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    manifest_path = args.manifest
    with open(manifest_path, encoding="utf-8") as manifest_file:
        manifest = json.load(manifest_file)

    if args.fix:
        base_url = manifest_self_href(manifest)
        if base_url is None:
            print(
                "Cannot fix manifest-only fixture without an absolute rel=self link: "
                f"{manifest_path}",
                file=sys.stderr,
            )
            return 1
        fix_hrefs(manifest, base_url)

    remaining_relative_hrefs = relative_hrefs(manifest)
    if remaining_relative_hrefs:
        unique_hrefs = list(dict.fromkeys(remaining_relative_hrefs))
        print(
            "Manifest-only fixtures must use absolute resource hrefs; "
            f"relative hrefs found in {manifest_path}: {unique_hrefs}",
            file=sys.stderr,
        )
        return 1

    if args.fix:
        json.dump(manifest, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
