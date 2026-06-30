#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/Resources/pdf"

TIME_MACHINE_URL="https://www.gutenberg.org/cache/epub/35/pg35-images.html"
ALICE_URL="https://www.gutenberg.org/cache/epub/11/pg11-images.html"

KNOWN_PDFS=(time_machine alice)

usage() {
  cat <<'EOF'
Usage:
  bin/regenerate-pdfs.sh [--output-dir DIR] [--chrome PATH] [--dry-run]
  bin/regenerate-pdfs.sh [--output-dir DIR] [--chrome PATH] [--dry-run] --preset NAME [--preset NAME ...]
  bin/regenerate-pdfs.sh [--output-dir DIR] [--chrome PATH] [--dry-run] --url URL --output FILE

Regenerates these PDFs from Project Gutenberg HTML:
  - time_machine.pdf
  - alice.pdf

Options:
  --output-dir DIR   Write PDFs to DIR (default: Resources/pdf)
  --chrome PATH      Explicit Chrome/Chromium binary path
  --preset NAME      Known PDF preset: time_machine or alice (repeatable)
  --url URL          Any gutenberg.org URL to render (requires --output)
  --output FILE      Output filename for --url (for example custom.pdf)
  --dry-run          Print commands without executing
  -h, --help         Show this help

Environment:
  CHROME_BIN         Explicit Chrome/Chromium binary path (same as --chrome)
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '%s\n' "$*"
}

is_gutenberg_url() {
  local url="$1"

  [[ "$url" =~ ^https?:// ]] || return 1
  [[ "$url" =~ ^https?://([a-zA-Z0-9.-]+\.)?gutenberg\.org(/|$) ]] || return 1

  return 0
}

preset_url() {
  local name="$1"

  case "$name" in
    time_machine)
      printf '%s\n' "$TIME_MACHINE_URL"
      ;;
    alice)
      printf '%s\n' "$ALICE_URL"
      ;;
    *)
      return 1
      ;;
  esac
}

is_known_preset() {
  local candidate="$1"
  local preset

  for preset in "${KNOWN_PDFS[@]}"; do
    [[ "$preset" == "$candidate" ]] && return 0
  done

  return 1
}

is_runnable_path() {
  local candidate="$1"

  [[ -n "$candidate" ]] || return 1

  if command -v "$candidate" >/dev/null 2>&1; then
    return 0
  fi

  [[ -x "$candidate" ]] && return 0

  # On Git Bash/WSL, .exe may exist but not report executable via -x.
  [[ -f "$candidate" && "$candidate" == *.exe ]] && return 0

  return 1
}

detect_chrome() {
  local explicit_bin="${1:-}"
  local cmd
  local candidate

  if [[ -n "$explicit_bin" ]]; then
    if is_runnable_path "$explicit_bin"; then
      printf '%s\n' "$explicit_bin"
      return 0
    fi

    fail "Chrome binary not found or not executable: $explicit_bin"
  fi

  if [[ -n "${CHROME_BIN:-}" ]]; then
    if is_runnable_path "$CHROME_BIN"; then
      printf '%s\n' "$CHROME_BIN"
      return 0
    fi

    fail "CHROME_BIN is set but not runnable: $CHROME_BIN"
  fi

  for cmd in google-chrome-stable google-chrome chromium chromium-browser chrome; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%s\n' "$cmd"
      return 0
    fi
  done

  for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/usr/bin/google-chrome" \
    "/usr/bin/chromium" \
    "/usr/bin/chromium-browser" \
    "/snap/bin/chromium" \
    "C:/Program Files/Google/Chrome/Application/chrome.exe" \
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
    "/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
    "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
  do
    if is_runnable_path "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  fail "Could not locate Chrome/Chromium. Install it or pass --chrome /path/to/binary"
}

render_pdf() {
  local chrome_bin="$1"
  local output_file="$2"
  local url="$3"
  local dry_run="$4"

  local -a args=(
    --headless=new
    --disable-gpu
    --no-pdf-header-footer
    "--print-to-pdf=$output_file"
    "$url"
  )

  if [[ "$dry_run" == "1" ]]; then
    log "DRY RUN: $chrome_bin ${args[*]}"
    return 0
  fi

  "$chrome_bin" "${args[@]}"
}

main() {
  local output_dir="$DEFAULT_OUTPUT_DIR"
  local explicit_chrome=""
  local dry_run="0"
  local custom_url=""
  local custom_output=""
  local -a selected_presets=()
  local preset
  local url

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --output-dir)
        [[ "$#" -ge 2 ]] || fail "Missing value for --output-dir"
        output_dir="$2"
        shift 2
        ;;
      --chrome)
        [[ "$#" -ge 2 ]] || fail "Missing value for --chrome"
        explicit_chrome="$2"
        shift 2
        ;;
      --dry-run)
        dry_run="1"
        shift
        ;;
      --preset)
        [[ "$#" -ge 2 ]] || fail "Missing value for --preset"
        is_known_preset "$2" || fail "Unknown preset: $2 (expected: time_machine, alice)"
        selected_presets+=("$2")
        shift 2
        ;;
      --url)
        [[ "$#" -ge 2 ]] || fail "Missing value for --url"
        custom_url="$2"
        shift 2
        ;;
      --output)
        [[ "$#" -ge 2 ]] || fail "Missing value for --output"
        custom_output="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done

  if [[ -n "$custom_url" && -z "$custom_output" ]]; then
    fail "--url requires --output FILE"
  fi

  if [[ -n "$custom_output" && -z "$custom_url" ]]; then
    fail "--output requires --url URL"
  fi

  if [[ -n "$custom_url" ]] && ! is_gutenberg_url "$custom_url"; then
    fail "--url must be a valid http(s) gutenberg.org URL"
  fi

  mkdir -p "$output_dir"
  output_dir="$(cd "$output_dir" && pwd)"

  local chrome_bin
  chrome_bin="$(detect_chrome "$explicit_chrome")"

  log "Using Chrome binary: $chrome_bin"
  log "Output directory: $output_dir"

  if [[ -n "$custom_url" ]]; then
    render_pdf "$chrome_bin" "$output_dir/$custom_output" "$custom_url" "$dry_run"

    if [[ "$dry_run" == "1" ]]; then
      log "Dry run complete."
    else
      log "Regenerated: $output_dir/$custom_output"
    fi

    exit 0
  fi

  if [[ "${#selected_presets[@]}" -eq 0 ]]; then
    selected_presets=("${KNOWN_PDFS[@]}")
  fi

  for preset in "${selected_presets[@]}"; do
    url="$(preset_url "$preset")" || fail "Unknown preset: $preset"
    render_pdf "$chrome_bin" "$output_dir/$preset.pdf" "$url" "$dry_run"
  done

  if [[ "$dry_run" == "1" ]]; then
    log "Dry run complete."
  else
    for preset in "${selected_presets[@]}"; do
      log "Regenerated: $output_dir/$preset.pdf"
    done
  fi
}

main "$@"
