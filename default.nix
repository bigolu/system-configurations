# In flake pure evaluation mode, `builtins.currentSystem` can't be accessed so we'll
# take system as a parameter.
import ./nix/dev/shells
# context@{ pkgs ? 4, system ? builtins.currentSystem}:
#   pkgs.lib.recursiveUpdate [
#     (import ./nix/public context)
#     (import ./nix/private)
#     (import ./nix/dev/shells)
#   ]
