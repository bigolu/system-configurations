set -o errexit
set -o nounset
set -o pipefail

if [ $# -eq 0 ]; then
  treefmt --on-unmatched=fatal --fail-on-change
else
  changed_file=

  # TODO: The output of `treefmt --help` says you can pass in multiple
  # paths, but it doesn't work
  for file in "$@"; do
    treefmt --on-unmatched=fatal --fail-on-change "$file" || changed_file=1
  done

  if [ -n "$changed_file" ]; then
    return 1
  else
    return 0
  fi
fi
