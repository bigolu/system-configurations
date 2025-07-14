# This file will be put on the NIX_PATH as 'nixpkgs' when we run cached-nix-shell for
# mise tasks. Since nixpkgs is a function that returns a package set, this needs to
# be a function as well.
_:
let
  packages = import ../private/packages;
in
  packages // {
    # nix-shell uses `pkgs.runCommandCC` to create the environment. We set it to
    # `runCommandNoCC` to make the closure smaller.
    pkgs.runCommandCC = packages.runCommandNoCC;
  }
