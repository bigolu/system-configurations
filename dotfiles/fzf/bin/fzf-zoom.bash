#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# TODO: Do this when Ghostty can be controlled remotely
exec fzf "$@"
