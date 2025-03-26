final: _prev: mkShell: args:
let
  inherit (builtins)
    removeAttrs
    catAttrs
    filter
    hasAttr
    ;
  inherit (final.lib)
    pipe
    optionalAttrs
    escapeShellArg
    concatStringsSep
    splitString
    concatLists
    unique
    ;

  # Prevent nested nix shells from executing this shell's hook:
  # https://git.lix.systems/lix-project/lix/issues/344
  makeSafeShellHookAndDedupInputsFrom =
    args@{
      # I need a name that won't conflict with the default one set by mkShell
      name ? "__nix_shell",
      inputsFrom ? [ ],
      ...
    }:
    let
      # This key will be added to the shell to keep track of the inputsFrom, in case
      # we need to merge this shell with another shell.
      uniqueInputsFromKey = "_inputsFrom";

      newInputsFrom = pipe inputsFrom [
        (catAttrs uniqueInputsFromKey)
        concatLists
        unique
      ];

      escapedName = escapeShellArg name;

      indent =
        string:
        pipe string [
          (splitString "\n")
          (map (line: "  " + line))
          (concatStringsSep "\n")
        ];

      allShellHooks = pipe args [
        (args: newInputsFrom ++ [ args ])
        (catAttrs "shellHook")
        (filter (hook: hook != ""))
        (concatStringsSep "\n")
        indent
      ];

      safeShellHook = ''
        function safe_shell_hook {
          # Check for a '-env' suffix since `nix develop` adds one:
          # https://git.lix.systems/lix-project/lix/src/commit/7575db522e9008685c4009423398f6900a16bcce/src/nix/develop.cc#L240-L241
          if [[ $name != ${escapedName} && $name != ${escapedName}'-env' ]]; then
            return
          fi

          ${allShellHooks}
        }
        safe_shell_hook
      '';

      shellWithoutInputsFrom = mkShell (removeAttrs args [ "inputsFrom" ]);

      newInputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) newInputsFrom;
    in
    args
    // {
      shellHook = safeShellHook;
      inputsFrom = newInputsFromWithoutShellHooks;
      "passthru".${uniqueInputsFromKey} = newInputsFrom ++ [ shellWithoutInputsFrom ];
    }
    // optionalAttrs (!hasAttr "name" args) { inherit name; };
in
pipe args [
  makeSafeShellHookAndDedupInputsFrom
  mkShell
]
