set -o errexit
set -o nounset
set -o pipefail

if [ "$1" = 'pr' ]; then
  reporter='-reporter=github-pr-review'
elif [ "$1" = 'commit' ]; then
  reporter='-reporter=github-check'
else
  echo 'Error: reporter type not specified' 1>&2
  exit 1
fi

found_problem=
run_linter() {
  "$@" || found_problem=1
}

format_and_make_suggestion() {
  name="$1"
  set -- "${@:2}"

  "$@" || true

  TMPFILE="$(mktemp)"
  git diff >"$TMPFILE"

  git stash -u

  reviewdog \
    -name="$name" \
    -f=diff \
    -f.diff.strip=1 \
    "$reporter" \
    -filter-mode=nofilter \
    -fail-on-error \
    -level=error \
    <"$TMPFILE"

  EXIT_CODE="$?"

  git stash drop || true

  return "$EXIT_CODE"
}

# Logic lints
run_linter reviewdog -fail-on-error -filter-mode=nofilter "$reporter"
run_linter bash scripts/lint/lint.bash --linters taplo,renovate,config-file-validator

# Style lints
run_linter format_and_make_suggestion taplo treefmt --formatters toml --on-unmatched debug
run_linter format_and_make_suggestion prettier treefmt --formatters prettier --on-unmatched debug
run_linter format_and_make_suggestion shfmt treefmt --formatters sh --on-unmatched debug
run_linter format_and_make_suggestion shfmt treefmt --formatters bash --on-unmatched debug
run_linter format_and_make_suggestion fish treefmt --formatters fish --on-unmatched debug
run_linter format_and_make_suggestion just treefmt --formatters justfile --on-unmatched debug
run_linter format_and_make_suggestion stylua treefmt --formatters lua --on-unmatched debug
run_linter format_and_make_suggestion gofmt treefmt --formatters go --on-unmatched debug
run_linter format_and_make_suggestion python-ruff-format treefmt --formatters python-ruff-format --on-unmatched debug
run_linter format_and_make_suggestion python-ruff-format-sort-imports treefmt --formatters python-ruff-format-sort-imports --on-unmatched debug
run_linter format_and_make_suggestion python-ruff-fix-lint treefmt --formatters python-ruff-fix-lint --on-unmatched debug
run_linter format_and_make_suggestion deadnix treefmt --formatters nix-deadnix --on-unmatched debug
run_linter format_and_make_suggestion statix treefmt --formatters nix-statix --on-unmatched debug
run_linter format_and_make_suggestion nixfmt treefmt --formatters nix-nixfmt --on-unmatched debug

if [ "$found_problem" = '1' ]; then
  exit 1
fi
