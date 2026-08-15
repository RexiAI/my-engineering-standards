#!/bin/bash
# install-opencode.sh — Download and extract the pinned opencode binary to
# /tmp/opencode-bin, then print its version.
#
# Shared by .github/workflows/self-ci.yml (model-env runtime verification) and
# .github/workflows/ci-sweeper.yml (the CI Sweeper sweep step). The two
# workflows must run the same opencode release, so the pin lives here once —
# bump the version in this file, not in two workflow files.
#
# Extract into its own dir: running a binary at /tmp/opencode makes opencode
# try to mkdir its storage dir at the same path → EEXIST.
set -euo pipefail

VERSION="v1.18.18"
mkdir -p /tmp/opencode-bin
curl -sSL -o /tmp/opencode-bin/opencode-linux-x64.tar.gz \
  "https://github.com/anomalyco/opencode/releases/download/${VERSION}/opencode-linux-x64.tar.gz"
tar -xzf /tmp/opencode-bin/opencode-linux-x64.tar.gz -C /tmp/opencode-bin
/tmp/opencode-bin/opencode --version
