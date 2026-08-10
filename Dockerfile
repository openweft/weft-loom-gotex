# Copyright (c) the weft-loom-gotex authors.
# SPDX-License-Identifier: BSD-3-Clause
#
# Pure-Go LaTeX compile sandbox image for weft-loom-server — a FROM scratch
# drop-in alternative to weft-loom-texlive. The whole image is a single static
# CGO=0 binary (`gotex`, from github.com/go-tex/engine) with a default font
# embedded: no TeX Live, no latexmk, no biber, no shell. Selected at runtime by
# weft-loom-server when a compile job requests `engine: "gotex"`; the TeX Live
# image remains the default, so both back-ends are maintained in parallel and
# nothing breaks.
#
# Invocation contract (identical artefact location to weft-loom-texlive):
#
#   docker run --rm \
#     -v <project>:/workspace:ro \
#     -v <scratch>:/workspace/.build:rw \
#     ghcr.io/openweft/weft-loom-gotex:latest \
#     -pdf -outdir=/workspace/.build /workspace/main.tex
#   → /workspace/.build/main.pdf

ARG GOTEX_VERSION=latest

FROM golang:1.26 AS build
ARG GOTEX_VERSION
ENV CGO_ENABLED=0 GOFLAGS=-trimpath
RUN go install -ldflags="-s -w" github.com/go-tex/engine/cmd/gotex@${GOTEX_VERSION} \
 && mv /go/bin/gotex /gotex

FROM scratch
COPY --from=build /gotex /gotex
WORKDIR /workspace
ENTRYPOINT ["/gotex"]
