#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gh local#nixpkgs.ripgrep local#nixpkgs.gitMinimal local#nixpkgs.coreutils --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

# TODO: Add debug mode that just logs what it would do, triggered by lack of
# github environment variable being set. This way I can test locally.

function main {
  readarray -t branches_with_pr \
    < <(gh pr list --json headRefName --jq '.[].headRefName' --repo "$GITHUB_REPOSITORY")
  # SYNC: AUTOMERGE_PREFIX
  readarray -t branches_to_automerge \
    < <(git branch --remotes --format '%(refname:lstrip=3)' | rg '^renovate/branch-automerge/')

  branches_to_automerge_without_pr=()
  for branch_to_automerge in "${branches_to_automerge[@]}"; do
    if ! is_item_in "$branch_to_automerge" "${branches_with_pr[@]}"; then
      branches_to_automerge_without_pr=("${branches_to_automerge_without_pr[@]}" "$branch_to_automerge")
    fi
  done

  gh alias set commit-status "api -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' --jq '.state' /repos/$GITHUB_REPOSITORY/commits/\$1/status"
  default_branch="$(git symbolic-ref --short HEAD)"

  for branch in "${branches_to_automerge_without_pr[@]}"; do
    echo $'\n'"Processing branch: $branch"
    absolute_branch="origin/$branch"

    if [[ "$(gh commit-status "$branch")" = 'failure' ]]; then # Failed check
      make_pr \
        "$branch" \
        'This branch has failing checks. Automerge has been disabled.'
    elif ! git merge-base --is-ancestor "$default_branch" "$absolute_branch"; then # Out of date
      if git rebase "$default_branch" "$absolute_branch"; then
        git push "$absolute_branch"
      else
        git rebase --abort
        make_pr \
          "$branch" \
          'This branch has merge conflicts with the default branch. Automerge has been disabled.'
      fi
      git switch "$default_branch"
    elif [[ "$(gh commit-status "$branch")" = 'success' ]]; then # Checks passed
      # newest commits first so take the last
      sha="$(git rev-list --ancestry-path "$default_branch".."$absolute_branch" | tail -1)"
      git merge --squash "$absolute_branch"
      git commit -m "$(get_commit_message "$sha")"
      git push "$default_branch"
    else # Pending checks
      continue
    fi
  done
}

function make_pr {
  gh pr create \
    --repo "$GITHUB_REPOSITORY" \
    --head "$1" \
    --base "$default_branch" \
    --title "$(get_commit_message "origin/$1")" \
    --body "$2"
}

function get_commit_message {
  git show --no-patch --format=%B "$1"
}

function is_item_in {
  local target="$1"
  shift

  local item
  for item in "$@"; do
    if [[ "$item" == "$target" ]]; then
      return 0
    fi
  done

  return 1
}

main
