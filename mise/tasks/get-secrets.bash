#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# GITHUB_TOKEN is for lychee
#
# shellcheck disable=2016
doppler run \
  --mount "${DEV_SHELL_STATE:?}/doppler-mount" \
  --mount-format 'env' \
  --only-secrets GH_TOKEN \
  --only-secrets GITHUB_TOKEN \
  --only-secrets RENOVATE_TOKEN \
  -- \
  bash -c 'cat "$DOPPLER_CLI_SECRETS_PATH" >.env'
