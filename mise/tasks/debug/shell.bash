# The first line in the file can't be a `nix-shell` directive because mise would misinterpret it as a shebang.
#! nix-shell -i bash
#! nix-shell --packages bash coreutils
#MISE description="Start `.#shell` in an empty environment"
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
env --ignore-environment TERM="${TERM:-}" HOME="$temp_home" "$shell"
