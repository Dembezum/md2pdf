# md2pdf

Convert GitHub-flavored Markdown into clean, PDFs using:

- Pandoc
- Chromium
- GitHub Markdown CSS
- Nix Flakes

The generated PDFs are optimized for technical documentation and include:

- Four document themes with packaged fonts
- Syntax highlighting
- Automatic table of contents
- Clean page layout
- Sensible page breaks
- Page numbers without browser URL/date headers
- Embedded styling for reproducible output

> See the [output here](./mdtest.pdf)

---

## Features

- GitHub style Markdown rendering
- Syntax highlighting via Pandoc
- Automatic Mermaid diagram rendering (SVG)
- Automatic table of contents
- Professional PDF layout
- Works entirely through `nix run`
- No local Pandoc or Chromium installation required
- Fully self-contained flake

---

## Usage

Generate a PDF from a Markdown file:

```bash
nix run git+ssh://git@dkgiteap01/<user>/md2pdf -- document.md
```

Example:

```bash
nix run git+ssh://git@dkgiteap01/<user>/md2pdf -- secrets.md
```

Output:

```text
secrets.pdf
```

The PDF is generated next to the source Markdown file.

---

## Mermaid

Mermaid code blocks are rendered automatically using Mermaid CLI. No additional
commands or downloads are needed once the Nix dependencies are available.

````markdown
```mermaid
flowchart TD
    A[Markdown] --> B[Pandoc]
    B --> C[Chromium]
    C --> D[PDF]
```
````

Diagrams are embedded as SVG images. Invalid Mermaid syntax stops the conversion.

---

## Repository Structure

```text
md2pdf/
├── flake.nix
├── run.sh
├── mermaid.lua
├── template.html
├── github-markdown.min.css
└── README.md
```

| File | Purpose |
| -------- | -------- |
| `flake.nix` | Nix flake definition |
| `run.sh` | Main conversion logic |
| `mermaid.lua` | Renders Mermaid code blocks as SVG |
| `template.html` | PDF rendering template |
| `github-markdown.min.css` | Embedded GitHub styling |
| `README.md` | Documentation |

---

## Output Pipeline

```text
Markdown
    ↓
Pandoc + Mermaid filter
    ↓
HTML
    ↓
GitHub Markdown CSS
    ↓
Chromium
    ↓
PDF
```

---

## Themes and layout

```bash
nix run . -- showcase.md
nix run . -- showcase.md --theme academic
nix run . -- showcase.md --theme professional --pagination sections
nix run . -- showcase.md --theme minimal --pagination flow --no-toc --no-footer
```

Themes: `technical` (default), `academic`, `professional`, `minimal`.

Pagination: `chapters` (default) starts H1 headings on new pages; `sections`
also starts H2 headings on new pages, except immediately after H1; `flow`
uses natural page breaks. All modes keep headings with following content.

Optional YAML metadata:

```yaml
---
title: Linux Fleet Management
subtitle: Architecture and implementation
author: Platform Engineering
version: 2.0
date: November 2026
cover: true
toc: true
theme: technical
pagination: chapters
---
```

CLI theme and pagination override metadata. Use `toc: false` or `--no-toc`
to omit the contents page. Cover pages require a title. Page numbers can be
removed with `--no-footer` and require Chromium support for CSS page margin boxes.
GitHub alerts and language-labelled fenced code blocks are styled automatically.
Local image paths are resolved relative to the Markdown file.
