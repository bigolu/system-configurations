{ lib, ... }:
let
  # This wraps a mkShell variant from nixpkgs (mkShell or mkShellNoCC). Instead of
  # just concatenating the given shellHook with the shellHooks from inputsFrom, this
  # wrapper will first deduplicate them. This way you can compose your shell of
  # smaller shells without worrying about hooks running more than once.
  mkShellUniqueWrapper =
    mkShell:
    args@{
      shellHook ? null,
      inputsFrom ? [ ],
      ...
    }:
    let
      inherit (lib)
        mergeAttrs
        flip
        concatStringsSep
        unique
        concatLists
        optionals
        pipe
        ;
      inherit (builtins) removeAttrs catAttrs;

      mergeAttrsBackwards = flip mergeAttrs;

      # This keys will be added to the shell to keep track of the individual
      # shellHooks that have been merged together, in case we need to merge that
      # shell with another shell.
      uniqueShellHooksKey = "_shellHooks";

      uniqueShellHooks =
        let
          uniqueShellHooksFromShellsToMergeWith = pipe inputsFrom [
            (catAttrs uniqueShellHooksKey)
            concatLists
          ];
        in
        unique (uniqueShellHooksFromShellsToMergeWith ++ optionals (shellHook != null) [ shellHook ]);

      mergedShellHooks = concatStringsSep "\n" uniqueShellHooks;

      # This way nixpkgs' mkShell doesn't also merge the shellHooks.
      inputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) inputsFrom;
    in
    pipe args [
      (mergeAttrsBackwards {
        shellHook = mergedShellHooks;
        inputsFrom = inputsFromWithoutShellHooks;
      })
      mkShell
      (mergeAttrs {
        ${uniqueShellHooksKey} = uniqueShellHooks;
      })
    ];
in
{
  flake.lib = {
    inherit mkShellUniqueWrapper;
  };
}
