# There are two reason for this file:
#   - For the various places where use `nix run` e.g. `nix run --file <this> ...`
#   - This file will be put on the NIX_PATH as 'nixpkgs' when we run cached-nix-shell
#     for mise tasks. This way all the packages we reference will come from here.

# Since nixpkgs is a function that returns a package set, this needs to be a function
# as well.
#
# In order to have the nix CLI automatically call this function, the argument must be
# a set with either no attributes or default values for all attributes.
{ }:
let
  inherit ((import ../.. { }).context) packages;
in
packages
// {
  # nix-shell uses `pkgs.runCommandCC` to create the environment. We set it to
  # `runCommandNoCC` to make the closure smaller.
  pkgs.runCommandCC = packages.runCommandNoCC;
}
