#!/usr/bin/env bash
set -euo pipefail

INPUT="$1"
NAME=$(basename "$INPUT" .md)

pandoc \
  -f gfm \
  -s \
  --toc \
  --toc-depth=3 \
  --highlight-style=pygments \
  --template=template.html \
  "$INPUT" \
  -o "/tmp/${NAME}.html"

chromium \
  --headless \
  --disable-gpu \
  --no-pdf-header-footer \
  --print-to-pdf="${NAME}.pdf" \
  "file:///tmp/${NAME}.html"
