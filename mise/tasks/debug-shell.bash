#nix --interpreter bash --packages bash coreutils
#MISE description="Start portable home in an empty environment"
#USAGE flag "-b --bundle" help="Use `nix bundle` (slower)"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ ${usage_bundle:-} == 'true' ]]; then
	shell="$(nix build --no-link --print-out-paths --file nix/flake-compat.nix outputsForCurrentSystem.packages.shell-bundle)"
else
	shell_directory="$(nix build --print-out-paths --no-link --file nix/flake-compat.nix outputsForCurrentSystem.packages.shell)/bin"
	# Use '*' so I don't have to hard code the program name
	shell="$(echo "$shell_directory"/*)"
fi

temp_home="$(mktemp --directory)"
function remove_temp_home {
	rm --recursive --force "$temp_home"
}
trap remove_temp_home EXIT

env --ignore-environment TERM="${TERM:-}" HOME="$temp_home" "$shell"
