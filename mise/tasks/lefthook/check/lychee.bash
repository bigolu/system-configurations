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

function main {
  local -ra files=("$@")

  local report_path
  report_path="$(mktemp --directory)/report"

  # lychee exits with 2 if it finds broken links, but I don't want this script to
  # exit if that happens.
  set +o errexit
  lychee \
    -vv --no-progress \
    --cache \
    --suggest --archive wayback \
    --format markdown --output "$report_path" \
    --include-verbatim --include-fragments \
    "${files[@]}"
  local -r lychee_exit_code=$?
  set -o errexit

  if ((lychee_exit_code == 2)); then
    publish_report "$report_path"
  else
    exit $lychee_exit_code
  fi
}

function publish_report {
  local -r report_path="$1"

  # Most CI systems, e.g. GitHub Actions, set CI to 'true'
  if [[ ${CI:-} == 'true' && ${CI_DEBUG:-} != true ]]; then
    make_github_issue_for_report "$report_path"
  else
    printf '%s\n' \
      "Report path: $report_path" \
      'Contents:' \
      "$(<"$report_path")"
    # Since this isn't being run in CI, we fail so lefthook can report the failure.
    # In CI, a GitHub issue would be created instead.
    exit 1
  fi
}

function make_github_issue_for_report {
  local -r report_path="$1"
  local -r issue_title='Link Checker Report'
  local existing_issue_number
  existing_issue_number="$(
    gh issue list \
      --json title,number \
      --jq ".[] | select(.title == '$issue_title') | .number"
  )"

  if [[ -n $existing_issue_number ]]; then
    gh issue edit --body-file "$report_path" "$existing_issue_number"
  else
    gh issue create --title "$issue_title" --body-file "$report_path"
  fi
}

main "$@"
