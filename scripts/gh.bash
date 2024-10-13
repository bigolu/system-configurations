#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gh local#nixpkgs.dotenv-cli local#nixpkgs.direnv --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=1090
source <(direnv dotenv bash <(my-sops decrypt ~/code/secrets/src/system-configurations/development.enc.env))

gh "$@"
