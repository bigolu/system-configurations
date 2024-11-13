#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

if [[ ${TERM_PROGRAM:-} != WezTerm ]]; then
  exec fzf "$@"
fi

wezterm cli zoom-pane --zoom

set +o errexit
fzf "$@"
fzf_exit_code=$?
set -o errexit

wezterm cli zoom-pane --unzoom

exit $fzf_exit_code
