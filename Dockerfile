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
# and a naive `FROM --platform=$TARGETPLATFORM golang:1.27` could never pull
# a base image for it even with QEMU installed. The scratch final stage has
# no OS content of its own, so it never needs a base-image manifest either.
# `go install` (unlike `go build -o`) writes a cross-compiled binary into a
# $GOOS_$GOARCH subdirectory of the default install path rather than the
# top-level one — and refuses outright ("cannot install cross-compiled
# binaries when GOBIN is set") if GOBIN is pinned to sidestep that, so GOBIN
# is not an option here. The leg matching the build stage's OWN native arch
# (linux/amd64 on a typical GitHub-hosted runner) is not a "cross-compile" by
# Go's own definition even though every other platform's leg in the same
# buildx invocation is, so it lands directly in $GOPATH/bin/gotex instead of
# the subdirectory — the mv below tries the subdirectory first and falls
# back to the top-level path for that one native leg.
ARG GOTEX_VERSION=latest

# ⛔ THIS TAG IS A FLOOR THE THING BEING BUILT CAN RAISE UNDER IT. The official
# golang images set GOTOOLCHAIN=local, deliberately — the image version IS the
# toolchain, and nothing is fetched at build time. So when go-tex/engine raised
# its own `go` directive, this image stopped being able to install it, and the
# weekly build went red on 2026-10-05 with:
#
#   go: github.com/go-tex/engine/cmd/gotex@latest:
#       github.com/go-tex/engine@v0.231.0 requires go >= 1.27.1
#       (running go 1.26.8; GOTOOLCHAIN=local)
#
# on all five legs at once. Raise this tag; do NOT unset GOTOOLCHAIN to make it
# go away, because then the image no longer says which toolchain built it.
#
# The minor floats on purpose (`1.27`, not `1.27.2`) so security patches arrive
# without a commit — and a pinned patch would break on the next directive raise
# just as surely as 1.26 did.
#
# ⚠ THE MARGIN IS CURRENTLY ZERO, which is worth knowing before the next raise.
# Measured 2026-10-12 by building this file, not by reading tag lists:
#
#   golang:1.27                  go1.27.2   on linux/amd64 AND linux/arm64
#   engine v0.255.0 requires     >= 1.27.2  <- already past the 1.27.1 above
#
# So it passes today with nothing to spare: the very next directive raise in
# go-tex/engine turns this red again, and the error above is what it will say.
#
# Read that error, do not reason about it from a tag. A `docker run golang:1.27
# go version` here first answered go1.27.1 — a STALE LOCAL IMAGE — and that
# number was nearly committed to this comment as a measurement. `--pull=always`
# is what made it true.
FROM --platform=$BUILDPLATFORM golang:1.27 AS build
ARG GOTEX_VERSION
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0 GOFLAGS=-trimpath GOOS=$TARGETOS GOARCH=$TARGETARCH
RUN go install -ldflags="-s -w" github.com/go-tex/engine/cmd/gotex@${GOTEX_VERSION} \
 && (mv "/go/bin/${TARGETOS}_${TARGETARCH}/gotex" /gotex 2>/dev/null || mv /go/bin/gotex /gotex)

FROM scratch
COPY --from=build /gotex /gotex
WORKDIR /workspace
ENTRYPOINT ["/gotex"]
