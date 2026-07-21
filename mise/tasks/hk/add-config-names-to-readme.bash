#nix --interpreter bash --packages bash perl
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
        inherit (builtins) attrNames;
        flake = import ./.;
        inherit (flake.inputs.nixpkgs.lib) concatMapStringsSep;
        configs = attrNames (flake.outputs.systemConfigs // flake.outputs.darwinConfigurations);
      in
      concatMapStringsSep " " (c: "`${c}`") configs
    '
)"

perl -wsi -pe '
  $count += s{(Valid config names are: ).*?(\.)}{$1$configs$2};
  END { die "failed to substitute" if $count != 1 }
' -- -configs="$configs" README.md
