#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.reviewdog --command bash

# shellcheck shell=bash

set -o errexit
shopt -s inherit_errexit
set -o nounset
set -o pipefail
shopt -s nullglob

reporter=
if [[ "${CI:-}" = 'true' ]]; then
  reporter='github-check'
else
  reporter='local'
fi

reviewdog \
  "-reporter=$reporter" \
  -filter-mode=nofilter \
  -fail-level=any \
  -level=error "$@"
