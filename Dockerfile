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

# Multi-arch: the build stage is pinned to --platform=$BUILDPLATFORM (the
# runner's own native arch, not the target one) so it cross-compiles via
# GOOS/GOARCH instead of running the Go toolchain itself under QEMU emulation
# for every target platform — this is what makes linux/loong64 buildable at
# all, since the official golang image publishes no linux/loong64 manifest
# and a naive `FROM --platform=$TARGETPLATFORM golang:1.26` could never pull
# a base image for it even with QEMU installed. The scratch final stage has
# no OS content of its own, so it never needs a base-image manifest either.
# GOBIN is set explicitly because `go install` (unlike `go build -o`) writes
# cross-compiled binaries into a $GOOS_$GOARCH subdirectory of the default
# install path rather than the top-level one — pinning GOBIN sidesteps that
# entirely, so the binary always lands at the same fixed path regardless of
# target platform.
ARG GOTEX_VERSION=latest

FROM --platform=$BUILDPLATFORM golang:1.26 AS build
ARG GOTEX_VERSION
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0 GOFLAGS=-trimpath GOOS=$TARGETOS GOARCH=$TARGETARCH GOBIN=/out
RUN mkdir -p /out && go install -ldflags="-s -w" github.com/go-tex/engine/cmd/gotex@${GOTEX_VERSION}

FROM scratch
COPY --from=build /out/gotex /gotex
WORKDIR /workspace
ENTRYPOINT ["/gotex"]
