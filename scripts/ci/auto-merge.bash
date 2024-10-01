#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gh local#nixpkgs.ripgrep local#nixpkgs.gitMinimal --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

# TODO: Add debug mode that just logs what it would do, triggered by lack of
# github environment variable being set. This way I can test locally.

function main {
  readarray -t branches_with_pr \
    < <(gh pr list --json headRefName --jq '.[].headRefName' --repo "$GITHUB_REPOSITORY")
  readarray -t branches_to_automerge \
    < <(git branch --remotes --format '%(refname:lstrip=3)' | rg '^renovate/branch-automerge/')

  branches_to_automerge_without_pr=()
  for branch_to_automerge in "${branches_to_automerge[@]}"; do
    if ! is_item_in "$branch_to_automerge" "${branches_with_pr[@]}"; then
      branches_to_automerge_without_pr=("${branches_to_automerge_without_pr[@]}" "$branch_to_automerge")
    fi
  done

  for branch_to_automerge_without_pr in "${branches_to_automerge_without_pr[@]}"; do
    labels=()
    if ! rg '^renovate/branch-automerge/fixup/' <<<"$branch_to_automerge_without_pr"; then
      labels=(--label automerge)
    fi

    gh pr create --repo "$GITHUB_REPOSITORY" --head "$branch_to_automerge_without_pr" --base "$(git symbolic-ref --short HEAD)" --title "$IGNORE_MARKER $(git show -s --format=%B "$branch_to_automerge_without_pr")" --body 'A renovate automergeable update.' "${labels[@]}"
  done

  while IFS= read -r pr_number; do
    echo "Processing PR #$pr_number"

    comment_body=
    if [[ "$(gh pr checks "$pr_number" --json bucket --jq '.[].bucket' --repo "$GITHUB_REPOSITORY" --required)" =~ 'fail' ]]; then
      # SYNC: NIX_BRANCH_PREFIX
      if [[ "$(gh pr view "$pr_number" --json headRefName --jq '.headRefName' --repo "$GITHUB_REPOSITORY")" == renovate/branch-automerge/flake-lock/* ]]; then
        # Since I track nixpkgs-unstable some failures are expected. Just close
        # the PR, delete the branch, and hope it passes next time since the lock
        # will get regenerated.
        gh pr close "$pr_number" --repo "$GITHUB_REPOSITORY" --delete-branch
        continue
      else
        echo 'Status checks failed'
        comment_body='A status check failed so auto-merging has been disabled.'
      fi
    elif [ "$(gh pr view "$pr_number" --json mergeable --jq '.mergeable' --repo "$GITHUB_REPOSITORY")" = CONFLICTING ]; then
      echo 'PR is conflicted'
      comment_body='This PR has a conflict with its base branch so auto-merging has been disabled.'
    fi

    if [ -n "$comment_body" ]; then
      old_title="$(gh pr view "$pr_number" --json title --jq '.title' --repo "$GITHUB_REPOSITORY")"
      gh pr edit "$pr_number" --repo "$GITHUB_REPOSITORY" \
        --remove-label automerge \
        --add-label automerge-failed \
        --title "[automerge-failed] $old_title"
      gh pr comment "$pr_number" --repo "$GITHUB_REPOSITORY" \
        --body "$comment_body"
    else
      gh pr update-branch "$pr_number" --repo "$GITHUB_REPOSITORY" --rebase
      gh pr merge "$pr_number" --repo "$GITHUB_REPOSITORY" --auto --squash
    fi
    # SYNC: AUTOMERGE_LABEL
  done < <(gh pr list --json number --jq '.[].number' --repo "$GITHUB_REPOSITORY" --label automerge)
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
