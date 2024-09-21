set -o errexit
set -o nounset
set -o pipefail

function main {
  if ! bash scripts/qa/qa.bash generate; then
    bash scripts/ci/report-from-diff.bash 'code-generation'
    return 1
  fi
}

main
