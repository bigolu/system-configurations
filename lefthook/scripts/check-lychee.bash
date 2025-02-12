#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gh lychee coreutils]"

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
    --archive wayback --suggest \
    --format markdown --output "$report_path" \
    --include-fragments \
    --hidden --include-verbatim "${files[@]}"
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

  # Most CI systems, e.g. GitHub Actions, set this variable to 'true'.
  if [[ ${CI:-} == 'true' ]]; then
    gh issue create --title 'Link Checker Report' --body-file "$report_path"
  else
    printf '%s\n' \
      "Report path: $report_path" \
      'Contents:' \
      "$(<"$report_path")"
  fi
}

main "$@"
