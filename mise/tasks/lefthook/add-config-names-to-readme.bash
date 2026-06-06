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
		--impure \
		--raw \
		--expr '
      let
        inherit (builtins) attrNames concatMap attrValues;
        flake = import ./nix/flake-compat.nix;
        inherit (flake.inputs.nixpkgs.lib) concatMapStringsSep uniqueStrings;
        homeConfigs = uniqueStrings (
          concatMap
            (lp: attrNames lp.homeConfigurations or {})
            (attrValues flake.outputs.legacyPackages)
        );
        darwinConfigs = attrNames flake.outputs.darwinConfigurations;
        configs = homeConfigs ++ darwinConfigs;
      in
      concatMapStringsSep " " (c: "`${c}`") configs
    '
)"

perl -wsi -pe '
  $count += s{(Valid config names are: ).*?(\.)}{$1$configs$2};
  END { die "failed to substitute" if $count != 1 }
' -- -configs="$configs" README.md
