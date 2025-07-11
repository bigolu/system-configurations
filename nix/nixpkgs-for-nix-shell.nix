# This file will be put on the NIX_PATH as 'nixpkgs' when we run cached-nix-shell for
# mise tasks. Since nixpkgs is a function that returns a package set, this needs to
# be a function as well. We replace runCommandCC with runCommandNoCC to make the
# shell smaller.
_: (import ./packages.nix).extend (_final: prev: { runCommandCC = prev.runCommandNoCC; })
