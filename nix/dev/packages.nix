# This file is for easy access to the private package set.
(import ../.. { }).debug.private.pkgs
// {
  # This file will be put on the NIX_PATH as 'nixpkgs' when we run cached-nix-shell
  # for mise tasks. Since nixpkgs is a function that returns a package set, this
  # needs to be a function as well.
  __functor =
    self:
    { _ ? null, }:
    self
    // {
      # nix-shell uses `pkgs.runCommandCC` to create the environment. We set it to
      # `runCommandNoCC` to make the closure smaller.
      pkgs.runCommandCC = self.runCommandNoCC;
    };
}
