#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.reviewdog --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

reporter=
if [[ "${CI:-}" = 'true' ]]; then
  reporter='github-check'
  fail_level='none'
else
  reporter='local'
  fail_level='any'
fi

reviewdog \
  "-reporter=$reporter" \
  -filter-mode=nofilter \
  "-fail-level=$fail_level" \
  -level=error "$@"
