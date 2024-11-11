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
    "${check_command[@]}"
    if [[ "${CI:-}" = 'true' ]] && has_uncommitted_changes; then
      git diff \
        | reviewdog -f=diff "${reviewdog_flags[@]}"
      # Remove changes in case another check runs after this one. I could drop the
      # stash as well, but in the event that this code accidentally runs when the
      # script is run locally, I don't want to permanently delete any changes.
      git stash --include-untracked
    fi
  fi
}

function has_uncommitted_changes {
  [[ -n "$(git status --porcelain)" ]]
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

main "$@"
