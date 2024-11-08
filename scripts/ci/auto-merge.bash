#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.jq local#nixpkgs.gh local#nixpkgs.ripgrep local#nixpkgs.gitMinimal local#nixpkgs.coreutils --command bash

# shellcheck shell=bash

set -o errexit
shopt -s inherit_errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# TODO: Add debug mode that just logs what it would do, triggered by lack of
# github environment variable being set. This way I can test locally.

function main {
  readarray -t branches_with_pr \
    < <(gh pr list --json headRefName --jq '.[].headRefName' --repo "$GITHUB_REPOSITORY")

  # SYNC: AUTOMERGE_PREFIX
  readarray -t branches_to_automerge \
    < <(git branch --remotes --format '%(refname:lstrip=3)' | rg '^renovate/branch-automerge/fixup/')

  branches_to_automerge_without_pr=()
  for branch_to_automerge in "${branches_to_automerge[@]}"; do
    if ! is_item_in "$branch_to_automerge" "${branches_with_pr[@]}"; then
      branches_to_automerge_without_pr+=("$branch_to_automerge")
    fi
  done

  default_branch="$(git symbolic-ref --short HEAD)"
  echo "default branch: $default_branch"

  gh alias set get-checks "api -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' --jq '.check_runs[]' /repos/$GITHUB_REPOSITORY/commits/\$1/check-runs"

  failure_states=(failure cancelled timed_out action_required)

  remote=origin

  git config user.name 'github-actions[bot]'
  git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

  for branch in "${branches_to_automerge_without_pr[@]}"; do
    echo $'\n'"Processing branch: $branch"

    absolute_branch="$remote/$branch"

    readarray -t checks < <(gh get-checks "$branch" | jq -c)

    if has_failure "${checks[@]}"; then
      echo 'has failure'
      make_pr "$branch" 'This branch has failing checks.'
    elif ! git merge-base --is-ancestor "$default_branch" "$absolute_branch"; then
      echo 'out of date'
      git switch "$branch"
      if git rebase "$default_branch"; then
        git push "$branch"
      else
        git rebase --abort
        make_pr "$branch" 'This branch has merge conflicts with the default branch.'
      fi

      git switch "$default_branch"
    elif all_checks_passed "${checks[@]}"; then
      echo 'all checks passed'
      git rebase "$absolute_branch"
      git push "$default_branch"
      git push --delete "$remote" "$branch"
    else
      echo 'assuming there are pending checks'
      continue
    fi
  done
}

function has_failure {
  for check in "$@"; do
    if
      [[ "$(jq '.status' <<<"$check")" = completed ]] \
        && is_item_in "$(jq '.conclusion' <<<"$check")" "${failure_states[@]}"
    then
      return 0
    fi
  done

  return 1
}

function all_checks_passed {
  for check in "$@"; do
    if
      [[ "$(jq '.status' <<<"$check")" != completed ]] \
        || is_item_in "$(jq '.conclusion' <<<"$check")" "${failure_states[@]}"
    then
      return 1
    fi
  done

  return 0
}

function make_pr {
  gh pr create \
    --repo "$GITHUB_REPOSITORY" \
    --head "$1" \
    --base "$default_branch" \
    --title "$(get_commit_message_first_line "$remote/$1")" \
    --body "$2 Automerge has been disabled."
}

function get_commit_message_first_line {
  git log --oneline --format=%s --max-count 1 "$1"
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
