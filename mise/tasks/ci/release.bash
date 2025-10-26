#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils gh
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

tag='latest'

function main {
  delete_old_release
  make_new_release
}

function delete_old_release {
  gh release delete "$tag" --yes --cleanup-tag
}

function make_new_release {
  local title
  title="$(date +'%Y.%m.%d')"

  local checksum_file
  checksum_file="$(mktemp --directory)/checksums.txt"
  # This way only the basenames of the assets will be put in the checksum file
  pushd assets >/dev/null
  sha256sum -- * >"$checksum_file"
  popd >/dev/null

  gh release create "$tag" \
    --latest \
    --title "$title" \
    --notes-file .github/release_notes.md \
    assets/* "$checksum_file"
}

function gh {
  if [[ ${CI:-} == 'true' ]]; then
    command gh "$@"
  else
    echo 'gh:' "$@" >&2
  fi
}

main
