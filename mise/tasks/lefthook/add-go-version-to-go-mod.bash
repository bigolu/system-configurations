#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter perl
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

version="$(nix eval --raw --file . context.nixpkgs.go.version)"
perl -wsi -pe '
  $count += s{(toolchain go).*}{$1$version}g;
  END { die "failed to substitute" if $count != 1 }
' -- -version="$version" gozip/go.mod
