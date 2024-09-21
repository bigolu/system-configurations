set -o errexit
set -o nounset
set -o pipefail

printf '\nRunning formatters...\n%s\n' "$(printf '=%.0s' {1..40})"

if [ $# -eq 0 ]; then
  if chronic treefmt --on-unmatched=fatal --fail-on-change; then
    echo 'No files were formattted'
  fi
else
  changed_file=

  # TODO: The output of `treefmt --help` says you can pass in multiple
  # paths, but it doesn't work
  for file in "$@"; do
    chronic treefmt --on-unmatched=fatal --fail-on-change "$file" || changed_file=1
  done

  if [ -n "$changed_file" ]; then
    return 1
  else
    echo 'No files were formattted'
    return 0
  fi
fi
