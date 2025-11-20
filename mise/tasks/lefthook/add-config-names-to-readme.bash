#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter perl
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

configs="$(
  # shellcheck disable=2016
  nix eval \
    --file . context.outputs \
    --apply '
      outputs:
        with builtins;
        concatStringsSep
          " "
          (
            map
            (name: "`${name}`")
            (attrNames (outputs.homeConfigurations // outputs.darwinConfigurations))
          )
    ' \
    --raw
)"

perl -wsi -pe '
  $count += s{(Valid config names are: ).*?(\.)}{$1$configs$2};
  END { die "failed to substitute" if $count != 1 }
' -- -configs="$configs" README.md
