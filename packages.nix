# This file provides easy access to the package set used inside the flake i.e. the
# `pkgs` argument that is passed to each flake-parts module[1]. This way code outside
# the flake, like nix-shell shebangs, can use the same packages.
#
# [1]: https://flake.parts/module-arguments.html?highlight=pkgs#pkgs
(import ./default.nix).currentSystem._module.args.pkgs
