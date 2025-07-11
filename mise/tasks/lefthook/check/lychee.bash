#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter gh lychee coreutils
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

github_issue_title='Link Checker Report'

function main {
  local -ra files=("$@")

  local report_path
  report_path="$(mktemp --directory)/report"

  # lychee exits with 2 if it finds broken links, but I don't want this script to
  # exit if that happens.
  set +o errexit
  lychee --format markdown --output "$report_path" "${files[@]}"
  local -r lychee_exit_code=$?
  set -o errexit

  if ((lychee_exit_code == 0)); then
    close_existing_github_issue
  elif ((lychee_exit_code == 2)); then
    add_workflow_url "$report_path"
    make_github_issue "$report_path"
  else
    exit $lychee_exit_code
  fi
}

function add_workflow_url {
  local -r report_path="$1"
  echo \
    "<footer><a href=\"${GITHUB_WORKFLOW_RUN_URL:-}\">Workflow run</a></footer>" \
    >>"$report_path"
}

function make_github_issue {
  local -r report_path="$1"

  local existing_issue_number
  existing_issue_number="$(find_existing_github_issue)"
  if [[ -n $existing_issue_number ]]; then
    gh issue edit --body-file "$report_path" "$existing_issue_number"
  else
    gh issue create --title "$github_issue_title" --body-file "$report_path"
  fi
}

function close_existing_github_issue {
  local existing_issue_number
  existing_issue_number="$(find_existing_github_issue)"
  if [[ -n $existing_issue_number ]]; then
    gh issue close "$existing_issue_number" \
      --reason 'not planned' \
      --comment "This issue was closed by a [subsequent, successful workflow run](${GITHUB_WORKFLOW_RUN_URL:-})."
  fi
}

function find_existing_github_issue {
  gh issue list \
    --json title,number \
    --jq ".[] | select(.title == \"$github_issue_title\") | .number"
}

function gh {
  if [[ ${CI:-} == 'true' && ${CI_DEBUG:-} != true ]]; then
    command gh "$@"
  else
    echo 'gh:' "$@" >&2
  fi
}

main "$@"
