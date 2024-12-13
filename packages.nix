# This file provides easy access to the package set used inside the flake, just
# import this file. This way code outside the flake can use the same packages, for
# consistency. For example, scripts with nix-shell shebangs.
(import ./default.nix).currentSystem._module.args.pkgs
