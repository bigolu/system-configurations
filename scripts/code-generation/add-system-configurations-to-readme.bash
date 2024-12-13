#! /usr/bin/env cached-nix-shell
#! nix-shell --keep PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"PACKAGES\")); [nix-shell-interpreter perl]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  configs="$(
    get_configs
    # Add a character to the end of the output to preserve trailing newlines.
    printf x
  )"
  configs="${configs::-1}"

  perl -0777 -w -i -pe \
    "s{(<!-- START_CONFIGURATIONS -->).*(<!-- END_CONFIGURATIONS -->)}{\$1$configs\$2}igs" \
    README.md
}

function get_configs {
  nix eval --raw --impure --expr "
    let
      flake = import ./default.nix;

      makeListItems = platformFetcher: configs: let
        makeListItem = name:
          \"  - \${name} / \${platformFetcher configs.\${name}}\";
      in
        builtins.concatStringsSep \"\n\" (map makeListItem (builtins.attrNames configs));

      getConfigsForAllPlatforms = key: let
        legacyPackagesPerPlatform = builtins.attrValues flake.outputs.legacyPackages;
      in
        builtins.foldl'
        (acc: configs: acc // configs)
        {}
        (map (lp: lp.\${key} or {}) legacyPackagesPerPlatform);

      homeManagerConfigNames = getConfigsForAllPlatforms \"homeConfigurations\";
      homeManagerPlatformFetcher = config: config.activationPackage.system;

      nixDarwinConfigNames = getConfigsForAllPlatforms \"darwinConfigurations\";
      nixDarwinPlatformFetcher = config: config.system.system;
    in
      ''


        - Home Manager

        \${makeListItems homeManagerPlatformFetcher homeManagerConfigNames}

        - nix-darwin

        \${makeListItems nixDarwinPlatformFetcher nixDarwinConfigNames}

      ''
  "
}

main
