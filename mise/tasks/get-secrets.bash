#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# It needs to end in `.env` for doppler to use the dotenv format
mount_path="$(mktemp --directory)/mount.env"

# GITHUB_TOKEN is for lychee
#
# shellcheck disable=2016
doppler run \
  --mount "$mount_path" \
  --only-secrets GH_TOKEN \
  --only-secrets GITHUB_TOKEN \
  --only-secrets RENOVATE_TOKEN \
  -- \
  bash -c 'cat "$DOPPLER_CLI_SECRETS_PATH" >secrets.env'
