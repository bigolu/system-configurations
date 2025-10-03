# - You can perform filtering on your roots which would be hard to do with
#   nix-direnv. For example, filtering your npins' pins based on which platforms they
#   apply to. This way, a macOS only pin won't have a GC root on Linux.
# - The option to show a diff of your dev shell when it changes. This useful for
#   verifying that a refactor doesn't change the dev shell or just seeing what has
#   changed.
# - Roots are joined into a single derivation so you'll only have a single GC root
#   per project. This is reduces noise in the full list of GC roots for your system
#   (/nix/var/nix/gcroots/auto).

{
  lib,
  nixpkgs,
  ...
}:
nixpkgs.callPackage (
  {
    dix,
    coreutils,
    writeTextFile,
  }:
  let
    inherit (lib)
      pipe
      escapeShellArg
      isStorePath
      attrsToList
      concatMap
      getExe
      mapAttrsToList
      optionalString
      isList
      genericClosure
      getExe'
      concatLines
      filter
      genAttrs'
      nameValuePair
      filterAttrs
      attrValues
      ;
    inherit (lib.strings) unsafeDiscardStringContext;

    handlers = {
      /*
        config    = storePath | list[config] | attrSet[string -> config]
        storePath = anything coercible to a store path
      */
      path =
        config:
        if isStorePath config then
          [ config ]
        else if isList config then
          concatMap handlers.path config
        else
          # The set returned from npins has `__functor`
          handlers.path (attrValues (removeAttrs config [ "__functor" ]));

      # There's an issue for having flakes retain a reference to their inputs[1].
      #
      # [1]: https://github.com/NixOS/nix/issues/6895
      flake =
        let
          getInputsClosure =
            {
              inputs,
              exclude ? [ ],
            }:
            let
              processInputs =
                let
                  # PERF: So we can compare inputs by their outPath instead of having
                  # to compare the entire attrset.
                  excludeMap = genAttrs' exclude (
                    # nix doesn't allow attribute keys to have string context[1].
                    #
                    # [1]: https://discourse.nixos.org/t/not-allowed-to-refer-to-a-store-path-error/5226/4
                    input: nameValuePair (unsafeDiscardStringContext input.outPath) true
                  );
                  removeExcluded = filterAttrs (
                    _name: input: !excludeMap ? ${unsafeDiscardStringContext input.outPath}
                  );

                  toClosureNodes = mapAttrsToList (
                    # Used by `genericClosure` for equality checks
                    _name: input: input // { key = input.outPath; }
                  );
                in
                inputs:
                pipe inputs [
                  removeExcluded
                  toClosureNodes
                ];
            in
            # There may be cycles if a user sets `inputs.foo.inputs.bar.follows = ""`
            # which would point bar to `self`. This is sometimes done to remove
            # unnecessary inputs like development-only inputs. `genericClosure` will
            # handle this case.
            genericClosure {
              startSet = processInputs inputs;
              # Non-Flake inputs will not have inputs
              operator = input: processInputs (input.inputs or { });
            };
        in
        config:
        pipe config [
          getInputsClosure
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath of any local flakes will not be a store path.
          # This includes the current flake and any inputs of type "path".
          (filter isStorePath)
        ];
    };

    makeDerivation =
      {
        roots,
        scriptConfig,
      }:
      let
        derivation = writeTextFile {
          name = "roots.txt";
          text = concatLines roots;
          passthru.script =
            let
              dixExe = getExe dix;
              ln = getExe' coreutils "ln";
              realpath = getExe' coreutils "realpath";

              rootPath =
                if scriptConfig.rootPath ? eval then
                  ''"${scriptConfig.rootPath.eval}"''
                else if scriptConfig.rootPath ? text then
                  escapeShellArg scriptConfig.rootPath.text
                else
                  escapeShellArg "dev-shell-gc-root";
            in
            ''
              # Users can't pass in the shell derivation since that would cause
              # infinite recursion: To get the shell's outPath, we need its shellHook
              # which would include this script. And to get this script, we need the
              # shell's outPath. Instead, we make the GC root at runtime.
              #
              # We can't always rely on `builtins.placeholder "out"` pointing to the
              # shell derivation because at least in the case of numtide/devshell,
              # the shellHook is not on the same derivation as the shell. In those
              # cases, we'll check certain environment variables that should have the
              # shell store path.
              new_shell=
              if [[ -n $DEVSHELL_DIR ]]; then
                new_shell="$DEVSHELL_DIR"
              else
                new_shell=${placeholder "out"}
              fi

              # The path to the GC roots derivation is included here to make it part
              # of the dev shell closure: ${derivation}

              if [[ ! ${rootPath} -ef "$new_shell" ]]; then
                # If the dev shell was bundled with `nix bundle`, then we shouldn't
                # make the GC root. We use `nix-store --query --hash` to see if the
                # path we want to make a root for is a valid store path. If it isn't,
                # the shell was probably bundled. Instead of making a root, we make a
                # plain symlink. This way, subsequent checks to see if the root is up
                # to date will pass and we won't have to keep running the
                # `nix-store --query --hash` command below which will be slower than
                # the `[[ ... -ef ... ]]` conditional above.
                if
                  type -P nix-store >/dev/null &&
                    nix-store --query --hash "$new_shell" >/dev/null 2>&1
                then
                  ${optionalString (scriptConfig.devShellDiff or true) ''
                    if [[ -e ${rootPath} ]]; then
                      ${dixExe} "$(${realpath} ${rootPath})" "$new_shell"
                    fi
                  ''}
                  nix-store --add-root ${rootPath} --realise "$new_shell" >/dev/null
                else
                  ${ln} --force --no-dereference --symbolic "$new_shell" ${rootPath}
                fi
              fi
            '';
        };
      in
      derivation;
  in
  config:
  pipe config.roots [
    attrsToList
    (concatMap ({ name, value }: handlers.${name} value))
    (
      roots:
      makeDerivation {
        inherit roots;
        scriptConfig = config.script;
      }
    )
  ]
) { }
