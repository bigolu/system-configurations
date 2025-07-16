# For easy access to the private package set.
(import ../.. { }).context.private.pkgs
// {
  # This file will be put on the NIX_PATH as 'nixpkgs' when we run cached-nix-shell
  # for mise tasks. Since nixpkgs is a function that returns a package set, this
  # needs to be a function as well.
  __functor =
    self:
    # In order to have the nix CLI automatically call this function, the argument
    # must be a set with either no attributes or default values for all attributes. I
    # can't make it empty because `statix` would replace it with `_` and it doesn't
    # support ignoring fixes with comments[1].
    #
    # [1]: https://github.com/oppiliappan/statix/issues/61
    {
      _ ? null,
    }:
    self
    // {
      # nix-shell uses `pkgs.runCommandCC` to create the environment. We set it to
      # `runCommandNoCC` to make the closure smaller.
      pkgs.runCommandCC = self.runCommandNoCC;
    };
}
