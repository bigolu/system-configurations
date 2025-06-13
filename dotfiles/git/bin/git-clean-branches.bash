#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

default_branch_path="$(git symbolic-ref refs/remotes/origin/HEAD)"
branch="${1:-${default_branch_path##*/}}"

merged_branches=$(git branch --merged "$branch" | grep -v " $branch$" || true)

if [[ -z $merged_branches ]]; then
  echo 'No branches to delete'
  exit
fi

printf "The following branches have already been merged to %s:\n%s\n" "$branch" "$merged_branches"
echo "Are these branches ok to delete? (y/n): "
read -r response
if [[ $response == "y" ]]; then
  echo "$merged_branches" | xargs -r git branch -d
  echo "Branches deleted"
else
  echo "No branches were deleted"
fi
