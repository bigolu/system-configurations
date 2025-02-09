#! /usr/bin/env nix-shell
#! nix-shell -I nixpkgs=./nix/nixpkgs.nix
#! nix-shell -i bash
#! nix-shell --packages "with (import ../nix/flake-package-set.nix); [bash direnv coreutils]"

# What this script does:
#   - Get direnv and its dependencies, Bash and coreutils, using the nix-shell
#     shebang at the top
#   - Allows you to specify a file to load besides .envrc. direnv is considering
#     adding support for this[1].
#   - Run `direnv allow`
#
# Usage:
#   <direnv_wrapper> <path_to_envrc> <direnv_arguments>...
#
# Since this script is not run from within the direnv environment, the shebang at the
# top works differently than the ones in other scripts:
#   - A relative path is used to access the package set instead of the
#     FLAKE_PACKAGE_SET_FILE environment variable. This is done because that variable
#     comes from the direnv environment.
#   - -I is used to set nixpkgs on the nix path. This is done because NIX_PATH is set
#     by the direnv environment.
#   - nix-shell is used instead of cached-nix-shell. This is done because
#     cached-nix-shell comes from the direnv environment.
#   - bash is used as the interpreter instead of nix-shell-interpreter. This is
#     because nix-shell-interpreter is only needed to work around an issue with
#     cached-nix-shell.
#
# Also worth noting that the path in -I is relative to the directory where this
# script is executed, which is assumed to be the root of the project, and the path in
# the import is relative to where the script file is.
#
# [1]: https://github.com/direnv/direnv/issues/348

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

envrc="${1:?}"
direnv_args=("${@:2}")

if [[ -e .envrc ]]; then
  temp="$(mktemp --directory)"
  backup="$temp/.envrc"

  mv .envrc "$backup"

  # This way if the trap fails to restore it, users can do it themselves.
  echo "Backed up .envrc to $backup" >&2
  # shellcheck disable=2064
  # I want the command substitution to evaluate now, not when the trap is run.
  trap "$(printf 'mv %q .envrc' "$backup")" SIGTERM ERR EXIT
fi

ln --symbolic "$envrc" .envrc
direnv allow .
direnv "${direnv_args[@]}"
rm .envrc
