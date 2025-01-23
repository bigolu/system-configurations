# This file will be put on the nix path as 'nixpkgs'. Since nixpkgs is a function
# that returns a package set, this needs to be a function as well.
_: import ./flake-package-set.nix
