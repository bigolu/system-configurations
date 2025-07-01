final: _prev: mkShell: args:
let
  inherit (builtins)
    removeAttrs
    catAttrs
    filter
    ;
  inherit (final.lib)
    pipe
    escapeShellArg
    concatStringsSep
    splitString
    concatLists
    unique
    ;

  adjustMkShellArgs =
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

      uniqueInputsFrom = pipe inputsFrom [
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
        (args: uniqueInputsFrom ++ [ args ])
        (catAttrs "shellHook")
        (filter (hook: hook != ""))
        (concatStringsSep "\n")
        indent
      ];

      safeShellHook = ''
        # Prevent nested nix shells from executing this shell's hook[1][2].
        #
        # Check for a '-env' suffix since `nix develop` adds one[3].
        #
        # [1]: https://git.lix.systems/lix-project/lix/issues/344
        # [2]: https://github.com/NixOS/nix/issues/8257
        # [3]: https://git.lix.systems/lix-project/lix/src/commit/7575db522e9008685c4009423398f6900a16bcce/src/nix/develop.cc#L240-L241
        if [[ $name == ${escapedName} || $name == ${escapedName}'-env' ]]; then
        ${allShellHooks}
        fi
      '';

      shellWithoutInputsFrom = mkShell (removeAttrs args [ "inputsFrom" ]);
      uniqueInputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) uniqueInputsFrom;
    in
    args
    // {
      shellHook = safeShellHook;
      inputsFrom = uniqueInputsFromWithoutShellHooks;
      "passthru".${uniqueInputsFromKey} = uniqueInputsFrom ++ [ shellWithoutInputsFrom ];
    };
in
pipe args [
  adjustMkShellArgs
  mkShell
]
