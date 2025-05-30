#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter coreutils]"
#MISE hide=true
#USAGE flag "--var <var>" var=#true help="An environment variable to set in `env` format"
#USAGE arg "<nix_shell_args>" var=#true help="Arguments to pass to `nix shell`"

# This is essentially `nix shell --ignore-environment`, but with the added ability to
# set environment variables. Also, variables that the terminal requires to function
# are automatically retained.
#
# TODO: Maybe this could be upstreamed? Add a `--set` flag to define and keep an
# environment variable, seems reasonable since there's already an `--unset` flag.
# Also add `--keep-terminal` or `--keep-interactive` to keep the terminal-related
# variables to preserve terminal functionality.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

eval "user_env_vars=(${usage_var:-})"
env_vars=(
  HOME="$HOME"
  "${user_env_vars[@]}"
)

for var in "${env_vars[@]}"; do
  var_name="$(cut -d'=' -f1 <<<"$var")"
  keep_flags+=(--keep "$var_name")
done

eval "user_nix_shell_args=(${usage_nix_shell_args:-})"
nix_shell_args=(
  --ignore-environment

  # These are read by CLIs to determine what terminal they're running in
  --keep TERM --keep TERM_PROGRAM --keep TERM_PROGRAM_VERSION
  # These are read by CLIs to determine the capabilities of the terminal they're
  # running in.
  --keep TERMINFO --keep TERMINFO_DIRS --keep COLORTERM

  "${keep_flags[@]}"

  # The user-provided args need to go last because they probably include `--command`
  # which must be last.
  "${user_nix_shell_args[@]}"
)

env "${env_vars[@]}" nix shell "${nix_shell_args[@]}"
