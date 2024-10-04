#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

branch="${1:-master}"

merged_branches=$(git branch --merged "$branch" | grep -v " $branch$" || true)

if [ "$merged_branches" = "" ]; then
  echo 'No branches to delete'
  exit
fi

printf "The following branches have already been merged to %s:\n%s\n" "$branch" "$merged_branches"
echo "Are these branches ok to delete? (y/n): "
read -r response
if [ "$response" = "y" ]; then
  echo "$merged_branches" | xargs -r git branch -d
  echo "Branches deleted"
else
  echo "No branches were deleted"
fi
