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
  local gc_root_directory
  gc_root_directory="$(mktemp --directory)"

  local derivation
  derivation="$(nix eval --raw --file . packages.shell-bundle.drvPath)"

  # The derivation relies on all the store paths in the bundle while the bundle
  # itself doesn't depend on anything. Therefore, even if we already have the bundle,
  # we'd still need all of the store paths that are in the bundle to make the
  # derivation so we'll add a GC root for the derivation as well.
  nix build --out-link "$gc_root_directory/derivation-gc-root" "$derivation"

  local bundle_gc_root="$gc_root_directory/bundle-gc-root"
  # This will print the GC root path, not the store path, so we suppress it
  nix-store --add-root "$bundle_gc_root" --realise "$derivation" >/dev/null

  nix build --no-link --file . packages.shell-bundle.tests

  realpath "$bundle_gc_root"
}

function copy_bundle_into_assets {
  local -r asset_directory="$1"
  local -r bundle_store_path="$2"

  local bundle_name_with_platform
  bundle_name_with_platform="$(get_name_with_platform "$bundle_store_path")"

  cp "$bundle_store_path" "${asset_directory}/${bundle_name_with_platform}"
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
