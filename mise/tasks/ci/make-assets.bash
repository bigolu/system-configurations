#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  local asset_directory
  asset_directory="$(register_asset_directory)"

  local bundle_store_path
  bundle_store_path="$(make_shell_bundle)"

  assert_bundle_meets_size_limit "$bundle_store_path"

  copy_bundle_into_assets "$asset_directory" "$bundle_store_path"
}

function register_asset_directory {
  local asset_directory
  asset_directory="$(mktemp --directory)"
  echo "asset-directory=$asset_directory" >>"${GITHUB_OUTPUT:-/dev/stderr}"

  echo "$asset_directory"
}

# Creates a bundle for the shell and prints its store path
function make_shell_bundle {
  local gc_root_path
  gc_root_path="$(mktemp --directory)/bundle-gc-root"
  nix build --impure --out-link "$gc_root_path" --print-out-paths \
    --expr 'with (import ./.); bundlers.rootless packages.shell'
}

function copy_bundle_into_assets {
  local -r asset_directory="$1"
  local -r bundle_store_path="$2"

  local bundle_name_with_platform
  bundle_name_with_platform="$(get_name_with_platform "$bundle_store_path")"

  cp "$bundle_store_path" "${asset_directory}/${bundle_name_with_platform}"
}

function assert_bundle_meets_size_limit {
  local -r bundle_file="$1"

  local -r max_size=350
  local size
  size="$(du -m "$bundle_file" | cut -f1)"
  if ((size > max_size)); then
    echo "Shell is too big: $size MB. Max size: $max_size"
    exit 1
  fi
}

# Example: /nix/store/<hash>-foo -> foo-x86_64-linux
function get_name_with_platform {
  local -r store_path="$1"

  local -r name="${store_path#*-}"

  # e.g. x86_64-linux
  local platform
  platform="$(uname -ms)"
  platform="${platform,,}"
  platform="${platform// /-}"

  echo "${name}-${platform}"
}

main "$@"
