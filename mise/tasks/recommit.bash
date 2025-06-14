#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter git gnused]"
#MISE description='Commit again with the last commit message used'
#USAGE long_about """
#USAGE   If you use the git commit-msg hook and it fails, you can run this command to
#USAGE   commit again using the last commit message you entered.
#USAGE """

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

backup="$(git rev-parse --absolute-git-dir)/info/recommit-backup-commit-file"

function main {
  if (($# == 0)); then
    if [[ -e $backup ]]; then
      local -a no_verify=()
      if [[ ${RECOMMIT_NO_VERIFY:-} == 'true' ]]; then
        no_verify+=('--no-verify')
      fi

      git commit "${no_verify[@]}" --edit --message "$(<"$backup")"
      exit 0
    else
      echo 'recommit: Unable to recommit, no commit message has been backed up yet' >&2
      exit 1
    fi
  fi

  local -r commit_file="$1"
  local -ra check_command=("${@:2}")

  backup "$commit_file"

  if ! "${check_command[@]}"; then
    printf '%s\n' \
      '' \
      'To commit again with the commit message you just entered, run the following command:' \
      '  mise run recommit' \
      'If you think the errors reported are false-positives, you can skip the commit-msg hook by running the following command:' \
      '  RECOMMIT_NO_VERIFY=true mise run recommit' \
      'NOTE: This will also skip the pre-commit hook.'
    exit 1
  fi
}

function backup {
  local -r commit_file="$1"

  # The first expression removes the diff added by `git commit --verbose`. The second
  # one removes any commented lines.
  sed \
    --expression '/# ------------------------ >8 ------------------------/,$d' \
    --expression '/^#/d' \
    "$commit_file" \
    >"$backup"
}

main "$@"
