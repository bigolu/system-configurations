{ self, ... }:
{
  flake.overlays.default = self.overlays.misc;

  flake.overlays.misc =
    final: prev:
    let
      inherit (final.lib)
        getExe
        mergeAttrs
        flip
        concatStringsSep
        unique
        concatLists
        optionals
        pipe
        ;
    in
    {
      makePortableShell = import ./make-portable-shell final prev;

      makeNixShellInterpreterWithoutTmp =
        {
          name ? "nix-shell-interpreter",
          interpreter,
        }:
        final.writeShellApplication {
          inherit name;
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

      # This wraps a mkShell variant from nixpkgs (mkShell or mkShellNoCC). Unlike
      # the mkShell it wraps, it deduplicates the given shellHook and the ones from
      # inputsFrom before concatenating them. This way you can compose your shell of
      # smaller shells without worrying about hooks running more than once.
      #
      # While I haven't run into this myself, one possible edge case is when two
      # shellHooks contain the same text, but do something different depending on how
      # many times they're run. Maybe because they reference a variable that will
      # have a different value when each one is run. Here's a contrived example:
      #   x=((x + 1))
      #   printf "$x"
      # If two shells had this hook, then one of them would be removed and the output
      # would be "1" instead of "12"
      mkShellUniqueWrapper =
        mkShell:
        args@{
          shellHook ? null,
          inputsFrom ? [ ],
          ...
        }:
        let
          inherit (builtins) removeAttrs catAttrs;

          # This key will be added to the shell to keep track of the individual
          # shellHooks that have been merged together, in case we need to merge that
          # shell with another shell.
          uniqueShellHooksKey = "_shellHooks";

          uniqueShellHooks = pipe inputsFrom [
            (catAttrs uniqueShellHooksKey)
            concatLists
            (inputsFromHooks: inputsFromHooks ++ optionals (shellHook != null) [ shellHook ])
            unique
          ];

          joinedShellHooks = concatStringsSep "\n" uniqueShellHooks;

          # This way nixpkgs' mkShell doesn't also merge the shellHooks.
          inputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) inputsFrom;
        in
        pipe args [
          # Merge backwards so these keys overwrite the ones in args
          (flip mergeAttrs {
            shellHook = joinedShellHooks;
            inputsFrom = inputsFromWithoutShellHooks;
          })
          mkShell
          (mergeAttrs {
            ${uniqueShellHooksKey} = uniqueShellHooks;
          })
        ];
    };
}
