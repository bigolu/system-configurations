# This wraps a mkShell variant from nixpkgs (mkShell or mkShellNoCC). Unlike the
# mkShell it wraps, it deduplicates the given shellHook and the ones from inputsFrom
# before concatenating them. This way you can compose your shell of smaller shells
# without worrying about hooks running more than once.
#
# While I haven't run into this myself, one possible edge case is when two shellHooks
# contain the same text, but do something different depending on how many times
# they're run. Maybe because they reference a variable that will have a different
# value when each one is run. Here's a contrived example: x=((x + 1)) printf "$x" If
# two shells had this hook, then one of them would be removed and the output would be
# "1" instead of "12"
#
# A way to avoid the edge case above would be to de-duplicate inputsFrom instead of
# shellHook. The problem is, unlike shellHook, you can't reference the inputsFrom of
# a shell so there would be no way for me to clear the inputsFrom of the shells being
# merged.
#
# TODO: See if this could be upstreamed

final: _prev: mkShell:
args@{
  shellHook ? null,
  inputsFrom ? [ ],
  ...
}:
let
  inherit (builtins) removeAttrs catAttrs;
  inherit (final.lib)
    mergeAttrs
    flip
    unique
    concatLists
    pipe
    optionals
    concatStringsSep
    ;

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
]
