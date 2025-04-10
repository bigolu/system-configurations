#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils]"
#MISE hide=true
#USAGE flag "--var <var>" help="An environment variable to set in `env` format"
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

# I'm not using `<<<` because it would add a trailing newline
readarray -t -d ' ' env_vars < <(printf '%s' "${usage_var:-}")

keep_flags=()
for var in "${env_vars[@]}"; do
  var_name="$(cut -d'=' -f1 <<<"$var")"
  keep_flags+=(--keep "$var_name")
done

# I'm not using `<<<` because it would add a trailing newline
readarray -t -d ' ' nix_shell_args < <(printf '%s' "${usage_nix_shell_args:-}")
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
  "${nix_shell_args[@]}"
)

env "${env_vars[@]}" nix shell "${nix_shell_args[@]}"
