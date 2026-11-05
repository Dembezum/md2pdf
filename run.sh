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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

NAME="$(basename "$INPUT" .md)"
DIR="$(dirname "$INPUT")"

HTML="$(mktemp --suffix=.html)"
TEMPLATE="$(mktemp --suffix=.html)"

cleanup() {
    rm -f "$HTML"
    rm -f "$TEMPLATE"
}

trap cleanup EXIT

sed \
    "s|github-markdown.min.css|file://$SCRIPT_DIR/github-markdown.min.css|g" \
    "$SCRIPT_DIR/template.html" \
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
