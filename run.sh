#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: md2pdf <file.md>"
    exit 1
}

[ $# -eq 1 ] || usage

INPUT="$1"

[ -f "$INPUT" ] || {
    echo "File not found: $INPUT"
    exit 1
}

NAME="$(basename "$INPUT" .md)"
DIR="$(dirname "$INPUT")"

HTML="$(mktemp --suffix=.html)"
TEMPLATE="$(mktemp --suffix=.html)"

cleanup() {
    rm -f "$HTML" "$TEMPLATE"
}

trap cleanup EXIT

CSS="$(cat "$MD2PDF_CSS")"

sed \
    "s|\$githubcss\$|$CSS|g" \
    "$MD2PDF_TEMPLATE" \
    > "$TEMPLATE"

pandoc \
    -f gfm \
    -s \
    --toc \
    --toc-depth=3 \
    --highlight-style=pygments \
    --template="$TEMPLATE" \
    "$INPUT" \
    -o "$HTML"

chromium \
    --headless \
    --disable-gpu \
    --no-pdf-header-footer \
    --print-to-pdf="$DIR/$NAME.pdf" \
    "file://$HTML"

echo "Generated $DIR/$NAME.pdf"
