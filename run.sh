#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo 'Usage: md2pdf <file.md> [more.md ...] [-o output.pdf] [--cover|--no-cover] [--number-sections] [--metadata-file file.yaml] [--theme technical|academic|professional|minimal] [--pagination smart|chapters|sections|flow] [--no-toc] [--no-footer]'
}

INPUTS=()
OUTPUT=''
PANDOC_OPTIONS=()
THEME=''
PAGINATION=''
TOC=true
FOOTER=true
COVER=''
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o|--output) OUTPUT="${2:?Missing output}"; shift 2 ;;
        --cover) COVER=true; shift ;;
        --no-cover) COVER=false; shift ;;
        --number-sections) PANDOC_OPTIONS+=(--number-sections); shift ;;
        --metadata-file) PANDOC_OPTIONS+=(--metadata-file "${2:?Missing metadata file}"); shift 2 ;;
        --theme) THEME="${2:?Missing theme}"; shift 2 ;;
        --pagination) PAGINATION="${2:?Missing pagination}"; shift 2 ;;
        --no-toc) TOC=false; shift ;;
        --no-footer) FOOTER=false; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) usage >&2; exit 1 ;;
        *) INPUTS+=("$1"); shift ;;
    esac
done
[ "${#INPUTS[@]}" -gt 0 ] || { usage >&2; exit 1; }
RESOURCE_PATH=''
for i in "${!INPUTS[@]}"; do
    input="${INPUTS[$i]}"
    [ -f "$input" ] || { echo "File not found: $input" >&2; exit 1; }
    INPUTS[$i]="$(realpath "$input")"
    dir="$(dirname "${INPUTS[$i]}")"
    RESOURCE_PATH="${RESOURCE_PATH:+$RESOURCE_PATH:}$dir"
done
if [ -z "$OUTPUT" ]; then
    if [ "${#INPUTS[@]}" -gt 1 ]; then
        echo 'Multiple inputs require -o output.pdf' >&2
        exit 1
    fi
    OUTPUT="${INPUTS[0]%.*}.pdf"
fi
OUTPUT="$(realpath -m "$OUTPUT")"
for input in "${INPUTS[@]}"; do
    [ "$OUTPUT" != "$input" ] || { echo 'Output must not overwrite an input' >&2; exit 1; }
done
DEFAULT_TITLE=''
if [ "${#INPUTS[@]}" -gt 1 ]; then
    DEFAULT_TITLE="$(python3 - "$OUTPUT" "${INPUTS[@]}" <<'PYTITLE'
from pathlib import Path
import os, re, sys
paths = [Path(p).parent for p in sys.argv[2:]]
common = Path(os.path.commonpath(paths))
if common.name.lower() in ('docs', 'documentation', 'doc'):
    common = common.parent
name = common.name if len(set(paths)) == 1 else Path(sys.argv[1]).stem
name = name or Path(sys.argv[1]).stem
print(re.sub(r'[-_]+', ' ', name).strip().title())
PYTITLE
)"
fi
export MD2PDF_DEFAULT_TITLE="$DEFAULT_TITLE" MD2PDF_COVER_OVERRIDE="$COVER"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export FONTCONFIG_FILE="$MD2PDF_FONTCONFIG"
export MD2PDF_THEME_OVERRIDE="$THEME" MD2PDF_PAGINATION_OVERRIDE="$PAGINATION" MD2PDF_TOC="$TOC" MD2PDF_FOOTER="$FOOTER"

# CSS is inserted into the template before Pandoc expands its variables.
python3 - "$MD2PDF_TEMPLATE" "$MD2PDF_CSS" "$MD2PDF_STYLES" "$WORK/template.html" <<'PY'
import pathlib, sys
source, github, styles, output = map(pathlib.Path, sys.argv[1:])
css = github.read_text() + '\n' + (styles / 'base.css').read_text() + '\n' + (styles / 'design.css').read_text()
output.write_text(source.read_text().replace('$md2pdf-css$', css.replace('$', '$$')))
PY

pandoc -f gfm+yaml_metadata_block -s --toc --toc-depth=3 \
    --lua-filter="$MD2PDF_MERMAID_FILTER" \
    --lua-filter="$MD2PDF_DESIGN_FILTER" \
    --highlight-style=pygments --embed-resources \
    --resource-path="$RESOURCE_PATH" --template="$WORK/template.html" \
    "${PANDOC_OPTIONS[@]}" "${INPUTS[@]}" -o "$WORK/document.html"

args=(--no-pdf-header-footer --headless --disable-gpu --no-first-run --user-data-dir="$WORK/chromium" --print-to-pdf="$WORK/output.pdf")
python3 "$MD2PDF_FINISH" prepare "$WORK/document.html"
chromium "${args[@]}" "file://$WORK/document.html"
[ -s "$WORK/output.pdf" ] || { echo "Chromium did not produce a PDF" >&2; exit 1; }
if python3 "$MD2PDF_FINISH" contents "$WORK/document.html" "$WORK/output.pdf"; then
    rm -- "$WORK/output.pdf"
    chromium "${args[@]}" "file://$WORK/document.html"
fi
[ -s "$WORK/output.pdf" ] || { echo "Chromium did not produce a PDF" >&2; exit 1; }
python3 "$MD2PDF_FINISH" finish "$WORK/document.html" "$WORK/output.pdf" "$WORK/final.pdf" "$FOOTER"
mv -- "$WORK/final.pdf" "$OUTPUT"
echo "Generated $OUTPUT"
