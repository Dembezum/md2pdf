#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo 'Usage: md2pdf <file.md> [--theme technical|academic|professional|minimal] [--pagination chapters|sections|flow] [--no-toc] [--no-footer]'
}

INPUT=''
THEME=''
PAGINATION=''
TOC=true
FOOTER=true
while [ "$#" -gt 0 ]; do
    case "$1" in
        --theme) THEME="${2:?Missing theme}"; shift 2 ;;
        --pagination) PAGINATION="${2:?Missing pagination}"; shift 2 ;;
        --no-toc) TOC=false; shift ;;
        --no-footer) FOOTER=false; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) usage >&2; exit 1 ;;
        *) [ -z "$INPUT" ] || { usage >&2; exit 1; }; INPUT="$1"; shift ;;
    esac
done
[ -f "$INPUT" ] || { echo "File not found: $INPUT" >&2; exit 1; }
INPUT="$(realpath "$INPUT")"
DIR="$(dirname "$INPUT")"
NAME="$(basename "$INPUT" .md)"
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
    --resource-path="$DIR" --template="$WORK/template.html" \
    "$INPUT" -o "$WORK/document.html"

args=(--no-pdf-header-footer --headless --disable-gpu --no-first-run --user-data-dir="$WORK/chromium" --print-to-pdf="$WORK/output.pdf")
python3 "$MD2PDF_FINISH" prepare "$WORK/document.html"
chromium "${args[@]}" "file://$WORK/document.html"
if python3 "$MD2PDF_FINISH" contents "$WORK/document.html" "$WORK/output.pdf"; then
    chromium "${args[@]}" "file://$WORK/document.html"
fi
[ -s "$WORK/output.pdf" ] || { echo "Chromium did not produce a PDF" >&2; exit 1; }
python3 "$MD2PDF_FINISH" finish "$WORK/document.html" "$WORK/output.pdf" "$WORK/final.pdf" "$FOOTER"
mv -- "$WORK/final.pdf" "$DIR/$NAME.pdf"
echo "Generated $DIR/$NAME.pdf"
