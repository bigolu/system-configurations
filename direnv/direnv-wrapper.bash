#! Though we don't use shebangs, nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -I nixpkgs=./nix/nixpkgs-for-nix-shell.nix
#! nix-shell -i bash
#! nix-shell --packages bash direnv coreutils

# This script is a wrapper for direnv that has the following extra features:
#   - Gets direnv and its dependencies, Bash and coreutils, using the nix-shell
#     directives at the top.
#   - Allows you to specify a file to load besides .envrc. There's an open issue for
#     this[1].
#   - Runs `direnv allow`. There's an open issue for this[2].
#
# Usage:
#   nix-shell <this_script> <path_to_envrc> <direnv_arguments>...
#
# Since this script is not run from within the direnv environment, the nix-shell
# directives at the top of the file work differently than the ones in other
# scripts:
#   - -I is used to set nixpkgs on the nix path. This is done because NIX_PATH is set
#     by the cached-nix-shell wrapper that comes from the direnv environment.
#   - nix-shell is used instead of cached-nix-shell. This is done because
#     cached-nix-shell comes from the direnv environment.
#   - bash is used as the interpreter instead of nix-shell-interpreter. This is
#     because nix-shell-interpreter is only needed to work around an issue with
#     cached-nix-shell.
#
# It's also worth noting that the path used with the -I flag is relative to the
# directory where this script is executed, which is assumed to be the root of
# the project.
#
# [1]: https://github.com/direnv/direnv/issues/348
# [2]: https://github.com/direnv/direnv/issues/227

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

envrc="${1:?}"
direnv_args=("${@:2}")

function clean_up {
  if [[ ${did_link_envrc:-} == 'true' ]]; then
    rm .envrc
  fi

  if [[ -e ${backup:-} ]]; then
    mv "$backup" .envrc
  fi
}
trap clean_up EXIT

if [[ -e .envrc ]]; then
  backup="$(mktemp --directory)/.envrc"
  mv .envrc "$backup"
  # This way, if the trap fails to restore it, users can do it themselves.
  echo "Backed up .envrc to $backup" >&2
fi

ln --symbolic "$envrc" .envrc
did_link_envrc='true'

direnv allow .
direnv "${direnv_args[@]}"
