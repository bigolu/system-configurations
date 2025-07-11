#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter perl
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

configs="$(nix eval --raw --file nix/config-names.nix)"
perl -wsi \
  -pe '$count += s{(replace `|system:init )(<).*?(>)}{$1$2$configs$3};' \
  -e 'END { die "failed to substitute" if $count != 2 }' \
  -- \
  -configs="$configs" \
  README.md
