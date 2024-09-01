set -o errexit
set -o nounset
set -o pipefail

found_changes=
run_code_generator_and_report_changes() {
  label="$1"
  set -- "${@:2}"

  "$@"
  if [ -z "$(git status --porcelain)" ]; then
    printf 'No changes found when running code generation for "%s".' "$label"
  else
    found_changes=1
    printf 'Found changes when running code generation for "%s". Diff:' "$label"
  fi

  git reset --hard
  git clean --force -d
}

# TODO: Don't hardcode these, use `just --dump`
run_code_generator_and_report_changes 'gomod2nix lock' just generate-gomod2nix-lock
run_code_generator_and_report_changes 'neovim plugin list' just generate-neovim-plugin-list
run_code_generator_and_report_changes 'readme table of contents' just generate-readme-table-of-contents
run_code_generator_and_report_changes 'go mod tidy' just go-mod-tidy

if [ "$found_changes" = '1' ]; then
  exit 1
fi
