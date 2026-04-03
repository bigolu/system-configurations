#!
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter perl
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

version="$(nix eval --raw --file nix/packages lixPackageSet.lix.version)"
perl -wsi -pe '
  $count += s{(lix-)[0-9]+(?:\.[0-9]+){0,2}}{$1$version}g;
  END { die "failed to substitute" if $count != 2 }
' -- -version="$version" README.md
