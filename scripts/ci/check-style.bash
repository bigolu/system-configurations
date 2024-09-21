set -o errexit
set -o nounset
set -o pipefail

function main {
  if ! treefmt --fail-on-change --on-unmatched debug; then
    bash scripts/ci/report-from-diff.bash 'formatter-auto-fixes'
    exit 1
  fi
}

main
