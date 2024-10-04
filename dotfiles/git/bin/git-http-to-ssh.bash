#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# See if remote url end in '.git'
if git config --get remote.origin.url | grep -P '\.git$' >/dev/null; then
  newURL=$(git config --get remote.origin.url | sed -r 's#(http.*://)([^/]+)/(.+)$#git@\2:\3#g')
else
  newURL=$(git config --get remote.origin.url | sed -r 's#(http.*://)([^/]+)/(.+)$#git@\2:\3.git#g')
fi

echo "Does this new url look fine? (y/n) : " "$newURL"
read -r response
if [[ "$response" = "y" ]]; then
  git remote set-url origin "$newURL"
  echo "Git remote updated."
else
  echo "Git remote unchanged."
fi
