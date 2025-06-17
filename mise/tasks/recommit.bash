#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter gnused]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  local -r commit_file="$1"
  local -ra check_command=("${@:2}")

  local commit_message
  commit_message="$(extract_commit_message "$commit_file")"

  set +o errexit
  "${check_command[@]}"
  local -r check_command_exit_code=$?
  set -o errexit

  if ((check_command_exit_code != 0)); then
    printf '%s\n' \
      '' \
      '[recommit] Commit message:' \
      "$commit_message"
  fi

  exit $check_command_exit_code
}

function extract_commit_message {
  local -r commit_file="$1"

  # The first expression removes the diff added by `git commit --verbose`. The second
  # one removes any commented lines.
  sed \
    --expression '/# ------------------------ >8 ------------------------/,$d' \
    --expression '/^#/d' \
    "$commit_file"
}

main "$@"
