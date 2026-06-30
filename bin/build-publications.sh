#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCES_DIR="$ROOT_DIR/Resources"

usage() {
  cat <<'EOF'
Usage:
  bin/build-publications.sh list
  bin/build-publications.sh build TARGET_DIR [PUBLICATION_ID]

Commands:
  list                         List all available publications.
  build TARGET_DIR             Build all publications into TARGET_DIR.
  build TARGET_DIR ID          Build only the matching publication.

Publication IDs are source-relative so they stay unique across formats.
Examples:
  epub/moby_dick
  webpub/epub/712199_ebook
  webpub/audiobook/38533
  webpub/audiobook+remote/39031_auth_audiobook
  pdf/alice
  cbz/sample_comic
  webpub/divina/50272-nota-comics
  downloaded/pepper-and-carrot-ep01
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  local tool_name="$1"

  command -v "$tool_name" >/dev/null 2>&1 || fail "Required tool not found: $tool_name"
}

single_json_file() {
  local dir_path="$1"
  local entry_count=0
  local json_count=0
  local json_path=""
  local entry_path

  while IFS= read -r entry_path; do
    entry_count=$((entry_count + 1))
    [[ -f "$entry_path" ]] || fail "Expected only files in $dir_path"

    if [[ "$entry_path" == *.json ]]; then
      json_count=$((json_count + 1))
      json_path="$entry_path"
    fi
  done < <(find "$dir_path" -mindepth 1 -maxdepth 1 | LC_ALL=C sort)

  [[ "$entry_count" -eq 1 ]] || fail "Expected exactly one file in $dir_path"
  [[ "$json_count" -eq 1 ]] || fail "Expected exactly one JSON file in $dir_path"

  printf '%s\n' "$json_path"
}

discover_publications() {
  local path
  local name
  local json_path

  for path in "$RESOURCES_DIR"/pdf/*.pdf; do
    [[ -e "$path" ]] || continue
    name="$(basename "$path" .pdf)"
    printf 'pdf/%s\tpdf\t%s\t%s.pdf\n' "$name" "$path" "$name"
  done

  for path in "$RESOURCES_DIR"/epub/*; do
    [[ -d "$path" ]] || continue
    name="$(basename "$path")"
    printf 'epub/%s\tepub\t%s\t%s.epub\n' "$name" "$path" "$name"
  done

  for path in "$RESOURCES_DIR"/webpub/epub/*; do
    [[ -d "$path" ]] || continue
    name="$(basename "$path")"
    printf 'webpub/epub/%s\twebpub\t%s\t%s.webpub\n' "$name" "$path" "$name"
  done

  for path in "$RESOURCES_DIR"/webpub/epub+audio/*; do
    [[ -d "$path" ]] || continue
    name="$(basename "$path")"
    printf 'webpub/epub+audio/%s\twebpub\t%s\t%s.webpub\n' "$name" "$path" "$name"
  done

  for path in "$RESOURCES_DIR"/webpub/audiobook/*; do
    [[ -d "$path" ]] || continue
    name="$(basename "$path")"
    printf 'webpub/audiobook/%s\taudiobook\t%s\t%s.audiobook\n' "$name" "$path" "$name"
  done

  for path in "$RESOURCES_DIR"/webpub/audiobook+remote/*; do
    [[ -d "$path" ]] || continue
    name="$(basename "$path")"
    json_path="$(single_json_file "$path")"
    printf 'webpub/audiobook+remote/%s\tremote-json\t%s\t%s\n' "$name" "$path" "$(basename "$json_path")"
  done

  for path in "$RESOURCES_DIR"/cbz/*; do
    [[ -d "$path" ]] || continue
    name="$(basename "$path")"
    printf 'cbz/%s\tcbz\t%s\t%s.cbz\n' "$name" "$path" "$name"
  done

  for path in "$RESOURCES_DIR"/webpub/divina/*; do
    [[ -d "$path" ]] || continue
    name="$(basename "$path")"
    printf 'webpub/divina/%s\tdivina\t%s\t%s.divina\n' "$name" "$path" "$name"
  done

  if [[ -d "$RESOURCES_DIR/downloaded" ]]; then
    for path in "$RESOURCES_DIR"/downloaded/*.cbz "$RESOURCES_DIR"/downloaded/*.divina; do
      [[ -f "$path" ]] || continue
      filename="$(basename "$path")"
      stem="${filename%.*}"
      printf 'downloaded/%s\tpre-built\t%s\t%s\n' "$stem" "$path" "$filename"
    done
  fi
}

list_publications() {
  printf 'ID\tTYPE\tOUTPUT\tSOURCE\n'

  discover_publications | LC_ALL=C sort | while IFS=$'\t' read -r publication_id kind source_path output_name; do
    printf '%s\t%s\t%s\t%s\n' "$publication_id" "$kind" "$output_name" "$source_path"
  done
}

collect_zip_entries() {
  local dir_path="$1"
  local exclude_entry="${2:-}"
  local entry_path

  cd "$dir_path"
  while IFS= read -r entry_path; do
    entry_path="${entry_path#./}"

    [[ -n "$entry_path" ]] || continue
    [[ "$entry_path" == "$exclude_entry" ]] && continue

    printf '%s\n' "$entry_path"
  done < <(find . -mindepth 1 -type f | LC_ALL=C sort)
}

build_flat_archive() {
  local source_dir="$1"
  local output_path="$2"
  local entry_path
  local entries=()

  while IFS= read -r entry_path; do
    entries+=("$entry_path")
  done < <(collect_zip_entries "$source_dir")

  [[ "${#entries[@]}" -gt 0 ]] || fail "No files found in $source_dir"

  rm -f "$output_path"
  (
    cd "$source_dir"
    zip -X0q "$output_path" "${entries[@]}"
  )
}

build_epub_archive() {
  local source_dir="$1"
  local output_path="$2"
  local entry_path
  local entries=()

  [[ -f "$source_dir/mimetype" ]] || fail "Missing mimetype in $source_dir"

  while IFS= read -r entry_path; do
    entries+=("$entry_path")
  done < <(collect_zip_entries "$source_dir" "mimetype")

  rm -f "$output_path"
  (
    cd "$source_dir"
    zip -X0q "$output_path" mimetype

    if [[ "${#entries[@]}" -gt 0 ]]; then
      zip -X0q "$output_path" "${entries[@]}"
    fi
  )
}

copy_pdf() {
  local source_path="$1"
  local output_path="$2"

  cp "$source_path" "$output_path"
}

copy_remote_json() {
  local source_dir="$1"
  local output_path="$2"
  local json_path

  json_path="$(single_json_file "$source_dir")"
  cp "$json_path" "$output_path"
}

build_publications() {
  local target_dir="$1"
  local selected_id="${2:-}"
  local matched=0
  local publication_id
  local kind
  local source_path
  local output_name
  local output_path

  mkdir -p "$target_dir"
  target_dir="$(cd "$target_dir" && pwd)"

  while IFS=$'\t' read -r publication_id kind source_path output_name; do
    if [[ -n "$selected_id" && "$publication_id" != "$selected_id" ]]; then
      continue
    fi

    matched=1
    output_path="$target_dir/$output_name"

    case "$kind" in
      pdf)
        copy_pdf "$source_path" "$output_path"
        ;;
      epub)
        build_epub_archive "$source_path" "$output_path"
        ;;
      webpub|audiobook)
        build_flat_archive "$source_path" "$output_path"
        ;;
      cbz|divina)
        build_flat_archive "$source_path" "$output_path"
        ;;
      pre-built)
        if [[ ! -f "$source_path" ]]; then
          require_tool python3
          local fixture_name="${publication_id#downloaded/}"
          printf 'Downloading %s...\n' "$fixture_name"
          python3 "$ROOT_DIR/bin/download_sample_fixtures.py" "$fixture_name"
        fi
        cp "$source_path" "$output_path"
        ;;
      remote-json)
        copy_remote_json "$source_path" "$output_path"
        ;;
      *)
        fail "Unsupported publication type: $kind"
        ;;
    esac

    printf 'Built %s -> %s\n' "$publication_id" "$output_path"
  done < <(discover_publications | LC_ALL=C sort)

  if [[ "$matched" -eq 0 ]]; then
    if [[ -n "$selected_id" ]]; then
      fail "Unknown publication id: $selected_id"
    fi

    fail "No publications found"
  fi
}

main() {
  local command="${1:-}"

  case "$command" in
    list)
      [[ "$#" -eq 1 ]] || fail "The list command does not take extra arguments"
      list_publications
      ;;
    build)
      [[ "$#" -ge 2 && "$#" -le 3 ]] || fail "Usage: bin/build-publications.sh build TARGET_DIR [PUBLICATION_ID]"
      require_tool zip
      build_publications "$2" "${3:-}"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage >&2
      [[ -n "$command" ]] && fail "Unknown command: $command"
      fail "Missing command"
      ;;
  esac
}

main "$@"