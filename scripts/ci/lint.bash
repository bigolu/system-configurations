set -o errexit
set -o nounset
set -o pipefail

function main {
  if ! check_lint || ! fix_lint; then
    exit 1
  fi
}

function check_lint {
  bash scripts/qa/qa.bash lint check
}

function fix_lint {
  if ! bash scripts/qa/qa.bash lint fix; then
    bash scripts/ci/report-from-diff.bash 'lint-auto-fixes'
    return 1
  fi
}

main
