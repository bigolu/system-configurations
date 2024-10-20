#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

echo

printf '\n%s\n' '- Home Manager'
# shellcheck disable=2016
nix eval --raw --impure --expr 'let x = import ./default.nix; in (builtins.concatStringsSep "\n" (map (name: "\n  - ${name} / ${x.outputs.homeConfigurations.${name}.activationPackage.system}") (builtins.attrNames x.outputs.homeConfigurations))) + "\n"'

printf '\n%s\n' '- nix-darwin'
# shellcheck disable=2016
nix eval --raw --impure --expr 'let x = import ./default.nix; in (builtins.concatStringsSep "\n" (map (name: "\n  - ${name} / ${x.outputs.darwinConfigurations.${name}.system.system}") (builtins.attrNames x.outputs.darwinConfigurations))) + "\n"'
