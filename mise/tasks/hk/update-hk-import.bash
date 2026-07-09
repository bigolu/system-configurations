#nix --interpreter bash --packages bash perl hk
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

version="$(hk version)"

perl -wsi -pe '
  $count += s{(v|hk@)[0-9]+\.[0-9]+\.[0-9]+}{$1$version}g;
  END { die "failed to substitute" if $count != 2 }
' -- -version="$version" hk.pkl
