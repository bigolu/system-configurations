#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gh local#nixpkgs.dotenv-cli --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

if ! gh auth status 1>/dev/null 2>&1; then
  my-sops exec-file ~/code/secrets/src/system-configurations/development.enc.env \
    'dotenv -e {} -p GITHUB_TOKEN' |
    gh auth login --with-token
fi

gh "$@"
