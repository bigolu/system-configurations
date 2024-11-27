#! /usr/bin/env cached-nix-shell
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter perl

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

      makeListItems = platformFetcher: configNames: let
        makeListItem = name:
          ''\ \ - \${name} / \${platformFetcher name}'';
      in
        builtins.concatStringsSep ''\n'' (map makeListItem configNames);

      homeManagerConfigNames = builtins.attrNames flake.outputs.homeConfigurations;
      homeManagerPlatformFetcher = name:
        flake.outputs.homeConfigurations.\${name}.activationPackage.system;

      nixDarwinConfigNames = builtins.attrNames flake.outputs.darwinConfigurations;
      nixDarwinPlatformFetcher = name:
        flake.outputs.darwinConfigurations.\${name}.system.system;
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
