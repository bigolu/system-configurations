final: _prev: mkShell: args:
let
  inherit (builtins) removeAttrs catAttrs filter;
  inherit (final.lib)
    unique
    concatLists
    pipe
    optionalAttrs
    escapeShellArg
    concatStringsSep
    splitString
    ;

  # De-Duplicate inputsFrom so you can compose your shell of smaller shells without
  # worrying about shellHooks running more than once.
  #
  # TODO: See if upstream thinks this behavior should be added to mkShell
  dedupInputsFrom =
    args@{
      inputsFrom ? [ ],
      ...
    }:
    let
      # This key will be added to the shell to keep track of the inputsFrom, in case
      # we need to merge this shell with another shell.
      uniqueInputsFromKey = "_inputsFrom";

      shellWithoutInputsFrom = mkShell (removeAttrs args [ "inputsFrom" ]);

      uniqueInputsFrom = pipe inputsFrom [
        (catAttrs uniqueInputsFromKey)
        concatLists
        unique
      ];
    in
    args
    // {
      inputsFrom = uniqueInputsFrom;
      "passthru".${uniqueInputsFromKey} = uniqueInputsFrom ++ [ shellWithoutInputsFrom ];
    };

  # Prevent nested nix shells from executing this shell's hook:
  # https://git.lix.systems/lix-project/lix/commit/7a12bc2007accb5022037b5a04b0e5475a8bb409
  makeSafeShellHook =
    args@{
      # I need a name that won't conflict with the default one set by mkShell
      name ? "__nix_shell",
      inputsFrom ? [ ],
      ...
    }:
    let
      escapedName = escapeShellArg name;

      indent =
        string:
        pipe string [
          (splitString "\n")
          (map (line: "  " + line))
          (concatStringsSep "\n")
        ];

      hook = pipe args [
        (args: inputsFrom ++ [ args ])
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

          ${hook}
        }
        safe_shell_hook
      '';

      inputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) inputsFrom;
    in
    args
    // {
      shellHook = safeShellHook;
      inputsFrom = inputsFromWithoutShellHooks;
    }
    // optionalAttrs (!args ? "name") { inherit name; };
in
pipe args [
  dedupInputsFrom
  makeSafeShellHook
  mkShell
]
