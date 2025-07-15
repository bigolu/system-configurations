{ pkgs, ... }:
  pkgs.callPackage
  (
    {
      uniqueShellHooks ? true,
      guardShellHook ? true,
      lib,
      mkShellNoCC,
    }:
      mkShellArgs:
      let
        inherit (builtins)
          removeAttrs
          catAttrs
          filter
          foldl'
          ;
        inherit (lib)
          pipe
          escapeShellArg
          concatStringsSep
          splitString
          concatLists
          unique
          optionals
          reverseList
          recursiveUpdate
          ;

        applyIf =
          shouldApply: function: arg:
          if shouldApply then function arg else arg;

        recursiveUpdateList = foldl' recursiveUpdate { };

        deduplicateShellHooks =
          mkShellArgs@{
            inputsFrom ? [ ],
            ...
          }:
          let
            uniquePropagatedShells = pipe inputsFrom [
              (catAttrs "propagatedShells")
              concatLists
              unique
            ];

            shellHooks = pipe uniquePropagatedShells [
              (catAttrs "shellHook")
              # mkShell defaults the shellHook to an empty string
              (filter (hook: hook != ""))
              # mkShell reverses the order of the shellHooks of the shells in inputsFrom
              reverseList
              (shellHooks: shellHooks ++ optionals (mkShellArgs ? "shellHook") [ mkShellArgs.shellHook ])
            ];

            joinedShellHooks = concatStringsSep "\n" shellHooks;
            inputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) inputsFrom;
            shellWithoutInputsFrom = mkShellNoCC (removeAttrs mkShellArgs [ "inputsFrom" ]);
          in
          recursiveUpdateList (
            [
              mkShellArgs
              {
                # We store all the shells included in inputsFrom, recursively, so we can
                # keep track of the individual shellHooks. We need to do this since mkShell
                # combines all the shellHooks from the shells in inputsFrom with the
                # shellHook of the shell being created.
                #
                # Even though the goal is only to deduplicate shellHooks, we keep track of
                # the entire shells so we can deduplicate the hooks based on the shell
                # derivation they belong to and not their contents. This way, if two
                # different shell derivations happen to have the same shellHook, the
                # shellHook will still be included twice.
                passthru.propagatedShells =
                  uniquePropagatedShells
                  # We include the shell being created so we can retain its original
                  # shellHook, before we joined it with the shellHooks from the
                  # propagatedShells in inputsFrom. We remove its inputsFrom since those
                  # shells are already included in their own propagatedShells, due to what
                  # we're doing here.
                  ++ [ shellWithoutInputsFrom ];
              }
            ]
            ++ optionals (inputsFromWithoutShellHooks != [ ]) [
              # Since we've already joined the shellHooks, we'll remove the shellHooks from
              # the shells in inputsFrom so they don't get joined again.
              { inputsFrom = inputsFromWithoutShellHooks; }
            ]
            ++ optionals (shellHooks != [ ]) [
              # We have to join the shellHooks ourselves since we store the individual
              # shellHooks in propagatedShells.
              { shellHook = joinedShellHooks; }
            ]
          );

        # Prevent nested nix shells from executing this shell's hook[1][2].
        #
        # [1]: https://git.lix.systems/lix-project/lix/issues/344
        # [2]: https://github.com/NixOS/nix/issues/8257
        addShellHookGuard =
          mkShellArgs@{
            # I need a name that won't conflict with the default one set by mkShell
            name ? "__nix_shell",
            inputsFrom ? [ ],
            ...
          }:
          let
            shellHooks = pipe inputsFrom [
              # deduplicateShellHooks will remove shellHooks from the shells in inputsFrom.
              # Since it doesn't know about the unguardedShellHook field added to the shell
              # here, it won't clear it. To work around this, we only read
              # unguardedShellHook if shellHook is also set.
              (filter (shell: shell ? "shellHook"))
              (catAttrs "unguardedShellHook")
              # mkShell defaults the shellHook to an empty string
              (filter (hook: hook != ""))
              # mkShell reverses the order of the shellHooks of the shells in inputsFrom
              reverseList
              (shellHooks: shellHooks ++ optionals (mkShellArgs ? "shellHook") [ mkShellArgs.shellHook ])
            ];

            indent =
              string:
              pipe string [
                (splitString "\n")
                (map (line: "  " + line))
                (concatStringsSep "\n")
              ];

            escapedName = escapeShellArg name;

            joinedShellHooks = concatStringsSep "\n" shellHooks;

            # Instead of putting a guard around each individual shellHook, we put
            # concatenate the hooks and put one guard around the entire thing. This is
            # necessary since the guard is dependent on the name of the dev shell and this
            # may change if a shell is included in another shell using inputsFrom.
            #
            # Since we do this, we have to remove the shellHooks from the shells in
            # inputsFrom.
            inputsFromWithoutShellHooks = map (shell: removeAttrs shell [ "shellHook" ]) inputsFrom;
            guardedShellHook = ''
              # Check for a '-env' suffix since `nix develop` adds one[1].
              #
              # [1]: https://git.lix.systems/lix-project/lix/src/commit/7575db522e9008685c4009423398f6900a16bcce/src/nix/develop.cc#L240-L241
              if [[ $name == ${escapedName} || $name == ${escapedName}'-env' ]]; then
                # Conditionals must have at least one command so I'll add one in case the
                # shellHook doesn't have one.
                :

              ${indent joinedShellHooks}
              fi
            '';
          in
          recursiveUpdateList (
            [ mkShellArgs ]
            ++ optionals (inputsFromWithoutShellHooks != [ ]) [
              { inputsFrom = inputsFromWithoutShellHooks; }
            ]
            ++ optionals (shellHooks != [ ]) [
              {
                shellHook = guardedShellHook;
                # The guard uses the name of the devShell, but the name may change if a
                # shell is included in another shell using inputsFrom so we'll store the
                # unguarded one as well.
                passthru.unguardedShellHook = joinedShellHooks;
              }
            ]
          );
      in
      pipe mkShellArgs [
        (applyIf uniqueShellHooks deduplicateShellHooks)
        (applyIf guardShellHook addShellHookGuard)
        mkShellNoCC
      ]
  )
  {}
