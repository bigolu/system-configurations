#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter gh lychee coreutils
#MISE hide=true

# TODO: Lychee's built-in file globbing didn't work for me. When I used
# `--dump-inputs` to see what files it would run on, I got the correct list, but when
# I actually ran it, it would run on a different set of files. I should look into
# this and possibly file an issue. Until this is fixed, I'm using this script which
# will get called by lefthook since lefthook can handle file globbing.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

issue_title='Link Checker Report'

function main {
  local -ra files=("$@")

  local report
  report="$(mktemp --directory)/report"

  # lychee exits with 2 if it finds broken links, but the script shouldn't exit if
  # that happens.
  set +o errexit
  lychee --format markdown --output "$report" "${files[@]}"
  local -r lychee_exit_code=$?
  set -o errexit

  if ((lychee_exit_code == 0)); then
    close_issue
  elif ((lychee_exit_code == 2)); then
    add_workflow_url "$report"
    open_issue "$report"
  else
    exit $lychee_exit_code
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
