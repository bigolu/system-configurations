set -o errexit
set -o nounset
set -o pipefail

if [ $# -eq 0 ]; then
  treefmt --on-unmatched=fatal
else
  # TODO: The output of `treefmt --help` says you can pass in multiple
  # paths, but it doesn't work
  for file in "$@"; do
    treefmt --on-unmatched=fatal "$file"
  done
fi
