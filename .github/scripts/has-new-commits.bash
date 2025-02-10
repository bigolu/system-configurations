#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gitMinimal]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# SYNC: NEW_COMMITS_SINCE
new_commits="$(git log -z --since '3 months ago')"
if [[ -n $new_commits ]]; then
  result='true'
else
  result='false'
fi
echo "result=$result" >>"${GITHUB_OUTPUT:-/dev/stderr}"
