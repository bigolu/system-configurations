#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter gitMinimal]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

hook_name="$1"

current_branch="$(git rev-parse --abbrev-ref HEAD)"
# shellcheck disable=2312
# I can't use a pipeline because I want to be able to `exit` this process.
readarray -t branches <(git config --get-all "auto-sync.$hook_name.branch")
for branch in "${branches[@]}"; do
  if [[ $branch == "$current_branch" ]]; then
    exit 0
  fi
done

# shellcheck disable=2312
# I can't use a pipeline because I want to be able to `exit` this process.
readarray -t shell_commands <(git config --get-all "auto-sync.$hook_name.shell")
for shell_command in "${shell_commands[@]}"; do
  if eval "$shell_command"; then
    exit 0
  fi
done

exit 1
