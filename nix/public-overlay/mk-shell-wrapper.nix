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
      ...
    }:
    let
      # This key will be added to the shell to keep track of the inputsFrom, in case
      # we need to merge this shell with another shell.
      uniqueInputsFromKey = "_inputsFrom";

      uniqueInputsFrom = pipe inputsFrom [
        (catAttrs uniqueInputsFromKey)
        concatLists
        unique
      ];

      joinedShellHooks = pipe uniqueInputsFrom [
        (catAttrs "shellHook")
        (shellHooks: shellHooks ++ optionals (args ? "shellHook") [ args.shellHook ])
        (filter (hook: hook != ""))
        (concatStringsSep "\n")
      ];

      shellWithoutInputsFrom = mkShellNoCC (removeAttrs args [ "inputsFrom" ]);
      uniqueInputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) uniqueInputsFrom;
    in
    args
    // {
      shellHook = joinedShellHooks;
      inputsFrom = uniqueInputsFromWithoutShellHooks;
      "passthru".${uniqueInputsFromKey} = uniqueInputsFrom ++ [ shellWithoutInputsFrom ];
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
