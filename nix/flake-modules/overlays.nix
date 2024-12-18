_: {
  flake.overlays.misc =
    final: prev:
    let
      inherit (final.lib) getExe;
    in
    {
      makeNixShellInterpreterWithoutTmp =
        {
          name ? "nix-shell-interpreter",
          interpreter,
        }:
        final.writeShellApplication {
          name = name;
          runtimeInputs = [ interpreter ];
          text = ''
            # TODO: nix-shell sets the temporary directory environment variables.
            # This is a problem because cached-nix-shell caches the environment
            # variables set by nix-shell so when I execute the shell again, the
            # temporary directory will not exist which will break any programs that
            # try to access it. To get around this, I use this script as my shebang
            # interpreter and then I unset the variables. I'm thinking that once nix
            # development environments are no longer made from build-debugging
            # environments, this won't be an issue anymore[1]. Otherwise, I should
            # see if cached-nix-shell could allow users to specify variables that
            # shouldn't get cached.
            #
            # [1]: https://github.com/NixOS/nixpkgs/pull/330822
            unset TMPDIR TEMPDIR TMP TEMP

            exec ${getExe interpreter} "$@"
          '';
        };
    };
}
