{
  guardShellHook ? true,
  uniqueShellHooks ? true,
  lib,
  mkShellNoCC,
  ...
}:
mkShellArgs:
let
  inherit (builtins)
    removeAttrs
    catAttrs
    filter
    ;
  inherit (lib)
    pipe
    escapeShellArg
    concatStringsSep
    splitString
    concatLists
    unique
    optionals
    ;

  uniqueShellHooksFunc =
    args@{
      inputsFrom ? [ ],
      shellHook ? "",
      ...
    }:
    let
      uniquePropagatedShells = pipe inputsFrom [
        (catAttrs "propagatedShells")
        concatLists
        unique
      ];

      joinedShellHooks = pipe uniquePropagatedShells [
        (catAttrs "shellHook")
        (shellHooks: shellHooks ++ [ shellHook ])
        (filter (hook: hook != ""))
        (concatStringsSep "\n")
      ];

      uniquePropagatedShellsWithoutShellHooks = map (
        shell: removeAttrs shell [ "shellHook" ]
      ) uniquePropagatedShells;

      shellWithoutInputsFrom = mkShellNoCC (removeAttrs args [ "inputsFrom" ]);
    in
    args
    // {
      # We have to join the shellHooks ourselves since we store the individual
      # shellHooks in propagatedShells.
      shellHook = joinedShellHooks;
      # Since we've already joined the shellHooks, we'll remove them from inputsFrom
      # so they don't get joined again.
      inputsFrom = uniquePropagatedShellsWithoutShellHooks;
      # We store all the shells included in inputsFrom, recursively, so we can keep
      # track of the individual shellHooks. We need to do this since mkShell combines
      # all the shellHooks from the shells in inputsFrom with the shellHook of the
      # shell being created.
      #
      # Even though the goal is only to deduplicate shellHooks, we keep track of the
      # entire shells so we can deduplicate the hooks based on the shell derivation
      # they belong to and not their contents. This way, if two different shell
      # derivations happen to have the same shellHook, the shellHook will still be
      # included twice.
      passthru.propagatedShells =
        uniquePropagatedShells
        # We include the shell being created so we can retain its original shellHook,
        # before we joined it with the shellHooks from the propagatedShells in
        # inputsFrom. We remove its inputsFrom since those shells are already
        # included in their own propagatedShells, due to what we're doing here.
        ++ [ shellWithoutInputsFrom ];
    };

  # Prevent nested nix shells from executing this shell's hook[1][2].
  #
  # [1]: https://git.lix.systems/lix-project/lix/issues/344
  # [2]: https://github.com/NixOS/nix/issues/8257
  guardShellHookFunc =
    args@{
      # I need a name that won't conflict with the default one set by mkShell
      name ? "__nix_shell",
      inputsFrom ? [ ],
      ...
    }:
    let
      indent =
        string:
        pipe string [
          (splitString "\n")
          (map (line: "  " + line))
          (concatStringsSep "\n")
        ];

      joinedShellHooks = pipe inputsFrom [
        (catAttrs "shellHook")
        (shellHooks: shellHooks ++ optionals (args ? "shellHook") [ args.shellHook ])
        (filter (hook: hook != ""))
        (concatStringsSep "\n")
        indent
      ];

      escapedName = escapeShellArg name;

      # Instead of putting a guard around each individual shellHook, we put
      # concatenate the hooks and put one guard around the entire thing. Since we do
      # this, we have to remove the shellHooks from the inputsFrom.
      inputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) inputsFrom;
      guardedShellHook = ''
        # Check for a '-env' suffix since `nix develop` adds one[1].
        #
        # [1]: https://git.lix.systems/lix-project/lix/src/commit/7575db522e9008685c4009423398f6900a16bcce/src/nix/develop.cc#L240-L241
        if [[ $name == ${escapedName} || $name == ${escapedName}'-env' ]]; then
        ${joinedShellHooks}
        fi
      '';
    in
    args
    // {
      inputsFrom = inputsFromWithoutShellHooks;
      shellHook = guardedShellHook;
    };

  applyIf =
    condition: function: arg:
    if condition then function arg else arg;
in
pipe mkShellArgs [
  (applyIf uniqueShellHooks uniqueShellHooksFunc)
  (applyIf guardShellHook guardShellHookFunc)
  mkShellNoCC
]
