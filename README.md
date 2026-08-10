# weft-loom-gotex

Pure-Go LaTeX compile sandbox image for
[weft-loom-server](https://github.com/openweft/weft-loom-server) — a **`FROM
scratch` drop-in alternative** to
[weft-loom-texlive](https://github.com/openweft/weft-loom-texlive).

The whole image is a **single static CGO=0 binary** (`gotex`, from
[go-tex/engine](https://github.com/go-tex/engine)) with a default font embedded:
no TeX Live, no `latexmk`, no `biber`, no shell — a few megabytes instead of
several gigabytes.

## Runtime selection (both back-ends in parallel)

weft-loom-server picks this image when a compile job requests
`engine: "gotex"`. The TeX Live image stays the default (`pdflatex` /
`lualatex` / `xelatex`), so the two implementations are maintained side by side
and selecting one never breaks the other.

## Invocation contract

```
docker run --rm \
  -v <project>:/workspace:ro \
  -v <scratch>:/workspace/.build:rw \
  ghcr.io/openweft/weft-loom-gotex:latest \
  -pdf -outdir=/workspace/.build /workspace/main.tex
```

Artefact lands at `/workspace/.build/main.pdf` — the same location
`weft-loom-texlive` produces, so weft-loom-server fetches it unchanged.

## Coverage

`gotex` compiles real LaTeX — `\documentclass`, `\maketitle`, numbered
sections, lists, `tabular`, automatic bold/italic, escaped specials, and
**math** (rendered as vector paths) — to a real PDF with the font embedded as a
subset. It is a growing subset of TeX Live; for documents it does not yet cover,
select the default TeX Live engine.

## Image

- Base: `scratch` (single static binary; the microVM provides kernel-level
  isolation).
- Engine: [github.com/go-tex/engine](https://github.com/go-tex/engine)
  (`cmd/gotex`), pure Go, `CGO_ENABLED=0`.
