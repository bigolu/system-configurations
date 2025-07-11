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

home="$(mktemp --directory)"

shell_flake_ref='.#shell'
if [[ ${usage_bundle:-} == 'true' ]]; then
  bundle_directory="$(mktemp --directory)"

  function delete_bundle_directory {
    rm -rf "$bundle_directory"
  }
  trap delete_bundle_directory EXIT

  nix bundle --out-link "$bundle_directory/bundled-shell" --bundler .# "$shell_flake_ref"
  shell_directory="$bundle_directory"
else
  shell_directory="$(nix build --print-out-paths --no-link "$shell_flake_ref")/bin"
fi

# Use '*' so I don't have to hard code the program name
shell_path="$(echo "$shell_directory"/*)"

mise run debug:make-isolated-env \
  --var HOME="$home" -- \
  --command "$shell_path"
