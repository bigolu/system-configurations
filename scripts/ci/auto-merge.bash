#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.jq local#nixpkgs.gh local#nixpkgs.ripgrep local#nixpkgs.gitMinimal local#nixpkgs.coreutils --command bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

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

  failure_states=(failure cancelled timed_out action_required)

  remote=origin

  git config user.name 'github-actions[bot]'
  git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

  readarray -t required_check_names < <(get_required_check_names)

  for branch in "${branches_to_automerge_without_pr[@]}"; do
    echo $'\n'"Processing branch: $branch"

    readarray -t checks < <(get_checks "$branch")

    if has_failure "${checks[@]}"; then
      echo 'has failure'
      make_pr "$branch" 'This branch has failing checks.'
    # TODO: If I remove $remote in $remote/$branch, then I get the following error,
    # but I don't understand why:
    # fatal: Not a valid object name <$branch>
    elif ! git merge-base --is-ancestor "$default_branch" "$remote/$branch"; then
      echo 'out of date'
      git switch "$branch"
      if git rebase "$default_branch"; then
        # A safer force push[1].
        #
        # [1]: https://stackoverflow.com/questions/65837109/when-should-i-use-git-push-force-if-includes
        git push --force-with-lease --force-if-includes
      else
        git rebase --abort
        make_pr "$branch" 'This branch has merge conflicts with the default branch.'
      fi

      git switch "$default_branch"
    elif all_required_checks_passed "${checks[@]}"; then
      echo 'all checks passed'
      # TODO: If I remove $remote in $remote/$branch, then I get the following error,
      # but I don't understand why:
      # fatal: invalid upstream <$branch>
      git rebase "$remote/$branch"
      git push
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

function all_required_checks_passed {
  for check in "$@"; do
    if ! is_item_in "$(jq '.name' <<<"$check")" "${required_check_names[@]}"; then
      continue
    fi

    if
      [[ "$(jq '.status' <<<"$check")" != completed ]] \
        || is_item_in "$(jq '.conclusion' <<<"$check")" "${failure_states[@]}"
    then
      return 1
    fi
  done

  return 0
}

function get_required_check_names {
  gh api \
    -H "Accept: application/vnd.github+json" \
    --jq '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context' \
    "/repos/$GITHUB_REPOSITORY/rules/branches/$default_branch"
}

function get_checks {
  gh api \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    --jq '.check_runs[]' \
    "/repos/$GITHUB_REPOSITORY/commits/$1/check-runs" \
    | jq --compact-output
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
