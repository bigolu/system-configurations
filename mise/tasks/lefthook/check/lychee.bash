#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gh lychee coreutils]"
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

  # Most CI systems, e.g. GitHub Actions, set CI to 'true'
  if [[ ${CI:-} == 'true' && ${CI_DEBUG:-} != true ]]; then
    gh issue create --title 'Link Checker Report' --body-file "$report_path"
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

main "$@"
