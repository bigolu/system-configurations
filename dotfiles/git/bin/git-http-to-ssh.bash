#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# See if the remote url ends in '.git'
if git config get remote.origin.url | grep -P '\.git$' >/dev/null; then
  new_url="$(
    git config get remote.origin.url |
      sed --regexp-extended 's#(http.*://)([^/]+)/(.+)$#git@\2:\3#g'
  )"
else
  new_url="$(
    git config get remote.origin.url |
      sed --regexp-extended 's#(http.*://)([^/]+)/(.+)$#git@\2:\3.git#g'
  )"
fi

echo "Does this new url look fine? (y/n): $new_url"
read -r response
if [[ $response == 'y' ]]; then
  git remote set-url origin "$new_url"
  echo 'Git remote updated.'
else
  echo 'Git remote unchanged.'
fi
