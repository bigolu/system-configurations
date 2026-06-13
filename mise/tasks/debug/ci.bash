#nix --interpreter bash --packages bash coreutils
#MISE description="Start a Bash shell in an environment that resembles CI"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Isolate the environment by using temporary directories for any directory that may
# be read from or written to.
temp_home="$(mktemp --directory)"
temp_prj_data_dir="$(mktemp --directory)"
function remove_temp_directories {
	rm --recursive --force "$temp_home" "$temp_prj_data_dir"
}
trap remove_temp_directories EXIT

env="$(type -P env)"
# Get the directory containing nix so we can add it to the PATH below
nix_path="$(type -P nix)"
nix_dir="${nix_path%/*}"

# Since we only assume that the CI machine has nix and git, they're the only programs
# added to the nix shell. We need git since flake-compat uses `builtins.fetchGit`
# which depends on it[1].
#
# [1]: https://github.com/NixOS/nix/issues/3533
PATH="$nix_dir" nix shell \
	--ignore-environment \
	--keep PATH \
	--file nix/packages.nix git \
	--command \
	"$env" \
	HOME="$temp_home" \
	PRJ_DATA_DIR="$temp_prj_data_dir" \
	nix run --file nix/flake-compat.nix outputsForCurrentSystem.devShells.ci -- bash --noprofile --norc
