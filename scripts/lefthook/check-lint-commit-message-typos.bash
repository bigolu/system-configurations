#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [gitMinimal]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# I'm using the merge-base in case the current branch is behind the default branch.
readarray -t commits_to_check \
  < <(git rev-list --abbrev-commit --ancestry-path "$(git merge-base origin/HEAD HEAD)"..HEAD)

found_problem=''
for commit in "${commits_to_check[@]}"; do
  commit_message_subject="$(git show --no-patch --format=%s "$commit")"
  echo "Checking commit $commit ($commit_message_subject)"
  commit_full_message="$(git show --no-patch --format=%B "$commit")"
  if ! typos --format brief - <<<"$commit_full_message"; then
    found_problem='true'
  fi
done

[[ $found_problem != 'true' ]]
