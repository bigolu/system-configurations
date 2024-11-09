#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.perl --command bash

# shellcheck shell=bash

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

  perl -0777 -w -i -pe "s{(<!-- START_CONFIGURATIONS -->).*(<!-- END_CONFIGURATIONS -->)}{\$1$configs\$2}igs" README.md
}

function get_configs {
  echo

  printf '\n%s\n' '- Home Manager'
  # shellcheck disable=2016
  nix eval --raw --impure --expr 'let x = import ./default.nix; in (builtins.concatStringsSep "\n" (map (name: "\n  - ${name} / ${x.outputs.homeConfigurations.${name}.activationPackage.system}") (builtins.attrNames x.outputs.homeConfigurations))) + "\n"'

  printf '\n%s\n' '- nix-darwin'
  # shellcheck disable=2016
  nix eval --raw --impure --expr 'let x = import ./default.nix; in (builtins.concatStringsSep "\n" (map (name: "\n  - ${name} / ${x.outputs.darwinConfigurations.${name}.system.system}") (builtins.attrNames x.outputs.darwinConfigurations))) + "\n"'

  echo
}

main
