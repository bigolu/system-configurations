set -o errexit
set -o nounset
set -o pipefail

found_changes=
run_code_generator_and_report_changes() {
  label="$1"
  set -- "${@:2}"

  "$@"
  if [ -z "$(git status --porcelain)" ]; then
    printf 'No changes found when running code generation for "%s".\n' "$label"
  else
    found_changes=1
    printf 'Found changes when running code generation for "%s". Diff:\n' "$label"
  fi

  git reset --hard
  git clean --force -d
}

run_code_generator_and_report_changes 'gomod2nix lock' bash ./scripts/generate-gomod2nix-lock.bash
run_code_generator_and_report_changes 'neovim plugin list' bash ./scripts/generate-neovim-plugin-list.bash
run_code_generator_and_report_changes 'readme table of contents' bash ./scripts/generate-readme-table-of-contents.bash
run_code_generator_and_report_changes 'go mod tidy' bash ./scripts/go-mod-tidy.bash

if [ "$found_changes" = '1' ]; then
  exit 1
fi
