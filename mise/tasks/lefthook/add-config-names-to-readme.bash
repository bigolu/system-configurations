# The first line in the file can't be a `nix-shell` directive because mise would misinterpret it as a shebang.
#! nix-shell -i bash
#! nix-shell --packages bash perl
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
