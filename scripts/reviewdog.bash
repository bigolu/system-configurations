#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.reviewdog --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

reporter=
if [[ "${CI:-}" = 'true' ]]; then
  reporter='-reporter=github-check'
else
  reporter='-reporter=local'
fi

reviewdog \
  "$reporter" \
  -filter-mode=nofilter \
  -fail-level=any \
  -level=error "$@"
