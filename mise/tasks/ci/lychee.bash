#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter gh lychee coreutils fd
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

issue_title='Link Checker Report'

function main {
  local report
  report="$(mktemp)"

  local lychee_exit_codes_file
  lychee_exit_codes_file="$(mktemp)"

  # TODO: Lychee's built-in file globbing didn't work for me. When I used
  # `--dump-inputs` to see what files it would run on, I got the correct list, but
  # when I actually ran it, it would run on a different set of files. I should look
  # into this and possibly file an issue. Until this is fixed, I'll use fd.
  #
  # shellcheck disable=2016
  fd \
    --hidden --type file \
    --exclude .git \
    --exclude gozip/gomod2nix.toml \
    --exclude '.vscode/ltex*' \
    --exclude 'dotfiles/keyboard/US keyboard - no accent keys.bundle/*' \
    --exclude dotfiles/cosmic/config \
    --exclude docs \
    --exclude lychee.toml \
    --exclude 'npins/*' \
    --exclude flake.lock \
    --exec-batch bash -c '
      lychee --format markdown "${@:3}" >>"$1"
      echo $? >>"$2"
    ' "$report" "$lychee_exit_codes_file"

  local did_fail
  local found_broken_link
  local -a lychee_exit_codes
  readarray -t lychee_exit_codes <"$lychee_exit_codes_file"
  for code in "${lychee_exit_codes[@]}"; do
    if ((code != 0 && code != 2)); then
      did_fail='true'
    elif ((code == 2)); then
      found_broken_link='true'
    fi
  done

  if [[ $did_fail == 'true' ]]; then
    echo 'exit codes:' "${lychee_exit_codes[@]}"
    exit 1
  elif [[ $found_broken_link == 'true' ]]; then
    add_workflow_url "$report"
    open_issue "$report"
  else
    # All calls were successful
    close_issue
  fi
}

function add_workflow_url {
  local -r report="$1"
  echo \
    "<footer><a href=\"${GITHUB_WORKFLOW_RUN_URL:-}\">Workflow run</a></footer>" \
    >>"$report"
}

function open_issue {
  local -r report="$1"

  local issue_number
  issue_number="$(find_issue)"
  if [[ -n $issue_number ]]; then
    gh issue edit --body-file "$report" "$issue_number"
  else
    gh issue create --title "$issue_title" --body-file "$report"
  fi
}

function close_issue {
  local issue_number
  issue_number="$(find_issue)"
  if [[ -n $issue_number ]]; then
    gh issue close "$issue_number" \
      --reason 'not planned' \
      --comment "This issue was closed by a [subsequent, successful workflow run](${GITHUB_WORKFLOW_RUN_URL:-})."
  fi
}

function find_issue {
  gh issue list \
    --json title,number \
    --jq ".[] | select(.title == \"$issue_title\") | .number"
}

function gh {
  if [[ ${CI:-} == 'true' && ${CI_DEBUG:-} != true ]]; then
    command gh "$@"
  else
    echo 'gh:' "$@" >&2
  fi
}

main "$@"
