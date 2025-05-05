#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_INTERNAL_PACKAGE_SET
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_INTERNAL_PACKAGE_SET\")); [nix-shell-interpreter gh lychee coreutils]"
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

  local running_in_ci
  running_in_ci="$(is_running_in_ci)"
  if [[ $running_in_ci != 'true' ]]; then
    printf '%s\n' \
      "Report path: $report_path" \
      'Contents:' \
      "$(<"$report_path")"
    # Since this isn't being run in CI, we fail so lefthook can report the failure.
    exit 1
  fi

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
    gh close "$existing_issue_number" \
      --reason 'not planned' \
      --comment "This issue was closed due to a [subsequent, successful workflow run](${GITHUB_WORKFLOW_RUN_URL:-})."
  fi
}

function find_existing_github_issue {
  gh issue list \
    --json title,number \
    --jq ".[] | select(.title == \"$github_issue_title\") | .number"
}

function gh {
  local running_in_ci
  running_in_ci="$(is_running_in_ci)"
  if [[ $running_in_ci == 'true' ]]; then
    command gh "$@"
  else
    echo 'gh spy:' "$@" >&2
  fi
}

function is_running_in_ci {
  # Most CI systems, e.g. GitHub Actions, set CI to 'true'
  if [[ ${CI:-} == 'true' && ${CI_DEBUG:-} != true ]]; then
    echo true
  fi
}

main "$@"
