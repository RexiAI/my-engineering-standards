#!/bin/bash
# install-opencode.sh — Download and extract the pinned opencode binary to
# /tmp/opencode-bin, then print its version.
#
# Shared by .github/workflows/self-ci.yml (model-env runtime verification),
# .github/workflows/ci-sweeper.yml (the CI Sweeper sweep step), and
# .github/workflows/ci-pr-review.yml (the PR review step). Every workflow
# must run the same opencode release, so the pin lives here once — bump the
# version (and the checksum below) in this file, not in three workflow files.
#
# Integrity check (spec 026, AC-026-04): the release tarball is verified
# against a SHA-256 pinned alongside the version, before it is ever extracted
# or executed. `curl` fetching a compromised or MITM'd asset without this
# check would silently run attacker binary in every workflow that calls this
# script — this is the single point where all of them would have been
# exposed. Recompute the checksum when bumping VERSION:
#   curl -sSL -o /tmp/o.tgz "https://github.com/anomalyco/opencode/releases/download/<new-version>/opencode-linux-x64.tar.gz"
#   sha256sum /tmp/o.tgz
#
# Extract into its own dir: running a binary at /tmp/opencode makes opencode
# try to mkdir its storage dir at the same path → EEXIST.
set -euo pipefail

VERSION="v1.18.18"
SHA256="0cddc222418b8553669905a8980c0cda7088f00da24d83d6ac76b01c9fdb2aaf"
ARCHIVE="/tmp/opencode-bin/opencode-linux-x64.tar.gz"

mkdir -p /tmp/opencode-bin
curl -sSL -o "$ARCHIVE" \
  "https://github.com/anomalyco/opencode/releases/download/${VERSION}/opencode-linux-x64.tar.gz"

echo "${SHA256}  ${ARCHIVE}" | sha256sum -c -

tar -xzf "$ARCHIVE" -C /tmp/opencode-bin
/tmp/opencode-bin/opencode --version
