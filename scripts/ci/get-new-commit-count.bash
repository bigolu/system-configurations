#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gitMinimal]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# SYNC: NEW_COMMITS_SINCE
readarray -d '' new_commits < <(git log -z --since '3 months ago')
new_commit_count=${#new_commits[@]}
echo "count=$new_commit_count" >>"$GITHUB_OUTPUT"
