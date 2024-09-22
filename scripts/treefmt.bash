set -o errexit
set -o nounset
set -o pipefail

reset='[m'
accent='[36m'
printf '\n\e%s┃ Format ❯\e%s\n' "$accent" "$reset"

if [ $# -eq 0 ]; then
  if ! chronic treefmt --on-unmatched=fatal --fail-on-change; then
    exit 1
  fi
else
  changed_file=

  # TODO: The output of `treefmt --help` says you can pass in multiple
  # paths, but it doesn't work
  for file in "$@"; do
    chronic treefmt --on-unmatched=fatal --fail-on-change "$file" || changed_file=1
  done

  if [ -n "$changed_file" ]; then
    exit 1
  fi
fi
