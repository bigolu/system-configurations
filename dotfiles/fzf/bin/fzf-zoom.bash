#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if [[ "${TERM_PROGRAM:-}" != WezTerm ]]; then
  exec fzf "$@"
fi

wezterm cli zoom-pane --zoom

fzf "$@"
fzf_exit_code=$?

wezterm cli zoom-pane --unzoom

exit $fzf_exit_code
