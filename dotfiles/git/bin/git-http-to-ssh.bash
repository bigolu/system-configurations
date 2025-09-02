#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

new_url="$(
  git remote get-url origin |
    # Ensure it ends in `.git`
    perl -pe 's|(http.*://)([^/]+)/(.+?)(\.git)?$|git@\2:\3.git|'
)"

echo "Does this new url look fine? (y/n): $new_url"
read -r response
if [[ $response == 'y' ]]; then
  git remote set-url origin "$new_url"
  echo 'Git remote updated.'
else
  echo 'Git remote unchanged.'
fi
