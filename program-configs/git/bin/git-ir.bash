#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

start_commit=''
if (($# == 0)) || [[ $1 == --* ]]; then
	# Rebase all the commits I haven't pushed yet.
	#
	# @{push} only exists if the branch has been pushed before.
	if git rev-parse '@{push}' >/dev/null 2>&1; then
		refs=('@{push}')
	else
		refs_string="$(git rev-parse --remotes)"
		readarray -t refs <<<"$refs_string"
	fi
	start_commit="$(git merge-base HEAD "${refs[@]}")"
elif ((${#1} <= 2)); then
	# The argument is probably a number specifying how many commits from HEAD I want to
	# rebase.
	start_commit="HEAD~$1"
	shift
else
	# The argument is a commit-ish specifying the first commit to be included in the
	# rebase.
	start_commit="$1^"
	shift
fi

# Save a reference to the commit we were on before the rebase started, in case we
# want to go back. To restore from this point use: git reset --hard refs/bigolu/ir-backup
git update-ref refs/bigolu/ir-backup HEAD

git rebase --interactive "$@" "$start_commit"
