#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.coreutils local#nixpkgs.reviewdog --command bash

# Usage:
#
# [this_script] [reviewdog_flags]... -- [check_command]...
#
# If reviewdog_flags does not contain an error format flag, -f or -efm, then it's
# assumed that the check_command will modify files. For example, a linter would set
# the error format, but a formatter wouldn't. In this case, the git diff, if any,
# will be reported.
#
# If reviewdog_flags does not contain the name flag, -name, then the first token in
# check_command will be used.

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  reviewdog_flags=(
    -filter-mode=nofilter
    -fail-level=any
    -level=error
  )
  check_command=()

  set_reviewdog_reporter
  parse_arguments "$@"
  run_check
}

function run_check {
  if did_set_reviewdog_error_format_flag; then
    "${check_command[@]}" | reviewdog "${reviewdog_flags[@]}"
  else
    if [[ "${CI:-}" = 'true' ]]; then
      "${check_command[@]}"

      if [[ -n "$(git status --porcelain)" ]]; then
        git diff \
          | reviewdog -f=diff -f.diff.strip=1 "${reviewdog_flags[@]}"
        # Remove changes in case another check runs after this one. I could drop the
        # stash as well, but in the event that this code accidentally runs when the
        # script is run locally, I don't want to permanently delete any changes.
        git stash --include-untracked
      fi
    else
      # When running locally, I need a fix command to fail if files change. This
      # failure will cause the pre-push hook to abort the push so I can fix up my
      # commits.
      fail_if_files_change "${check_command[@]}"
    fi
  fi
}

function did_set_reviewdog_error_format_flag {
  for flag in "${reviewdog_flags[@]}"; do
    if [[ "$flag" =~ ^-(f|efm)(=|$) ]]; then
      return 0
    fi
  done

  return 1
}

function set_reviewdog_reporter {
  if [[ "${CI:-}" = 'true' ]]; then
    # TODO: Due to a bug in GitHub Actions, the checks reported by reviewdog get
    # associated with the wrong workflow[1]. This discussion seems to be tracking the
    # issue[2]. In the meantime, I'll use the annotations reporter which was made
    # specifically to work around this issue[3].
    #
    # [1]: https://github.com/reviewdog/reviewdog/issues/403
    # [2]: https://github.com/orgs/community/discussions/24616
    # [3]: https://github.com/reviewdog/reviewdog/pull/1623
    reviewdog_flags+=(-reporter=github-pr-annotations)
  fi
}

function parse_arguments {
  did_reach_end_of_reviewdog_flags=
  did_set_reviewdog_name_flag=

  for argument in "$@"; do
    if [[ "$did_reach_end_of_reviewdog_flags" ]]; then
      check_command+=("$argument")
    elif [[ "$argument" = '--' ]]; then
      did_reach_end_of_reviewdog_flags=1
    else
      reviewdog_flags+=("$argument")
      if [[ "$argument" =~ ^-name(=|$) ]]; then
        did_set_reviewdog_name_flag=1
      fi
    fi
  done

  if [[ ! "$did_set_reviewdog_name_flag" ]]; then
    reviewdog_flags+=("-name" "${check_command[0]}")
  fi
}

function fail_if_files_change {
  diff_before_running="$(diff_including_untracked)"
  "$@"
  diff_after_running="$(diff_including_untracked)"

  if [[ "$diff_before_running" != "$diff_after_running" ]]; then
    return 1
  else
    return 0
  fi
}

function diff_including_untracked {
  readarray -d '' untracked_files < <(git ls-files -z --others --exclude-standard)
  track_files "${untracked_files[@]}"
  git diff
  untrack_files "${untracked_files[@]}"
}

function track_files {
  if (($# > 0)); then
    git add --intent-to-add -- "$@"
  fi
}

function untrack_files {
  if (($# > 0)); then
    git reset --quiet -- "$@"
  fi
}

main "$@"
