#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter coreutils]"

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
