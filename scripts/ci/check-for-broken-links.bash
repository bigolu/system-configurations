#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gh lychee coreutils]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  local -r report_path="$(mktemp --directory)/report"

  # lychee exits with a non-zero code if it finds broken links, but I don't want this
  # script to exit if that happens.
  set +o errexit
  lychee \
    --verbose --no-progress \
    --archive wayback --suggest \
    --format markdown --output "$report_path" \
    --include-fragments \
    --hidden --include-verbatim .
  set -o errexit

  if [[ ! -e $report_path ]]; then
    # If no report was generated, then something went wrong
    exit 1
  fi

  publish_report "$report_path"
}

function publish_report {
  local -r report_file="$1"

  if is_running_in_ci; then
    gh issue create --title 'Link Checker Report' --body-file "$report_path"
  else
    printf '%s\n' \
      "Report file: $report_file" \
      'Contents:' \
      "$(<"$report_file")"
  fi
}

function is_running_in_ci {
  # Most CI systems, e.g. GitHub Actions, set this variable to 'true'.
  [[ ${CI:-} == 'true' ]]
}

main
