#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils
#MISE description="Start `.#shell` in an empty environment"
#USAGE flag "-b --bundle" help="Use `nix bundle` (slower)"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ ${usage_bundle:-} == 'true' ]]; then
  shell="$(nix build --no-link --print-out-paths --file . packages.shell-bundle)"
else
  shell_directory="$(nix build --print-out-paths --no-link --file . packages.shell)/bin"
  # Use '*' so I don't have to hard code the program name
  shell="$(echo "$shell_directory"/*)"
fi

temp_home="$(mktemp --directory)"
env --ignore-environment HOME="$temp_home" "$shell"
