# There's an issue for having flakes retain a reference to their inputs[1].
#
# [1]: https://github.com/NixOS/nix/issues/6895#issuecomment-2475461113

# - Having all your roots in one place makes it easy to search them
# - You can perform filtering on your roots which would be hard to do with
#   nix-direnv. For example, filtering your npins' pins based on which platforms they
#   apply to. This way, a macOS only pin won't have a GC root on Linux.
# - Roots can be prefixed with names which is especially useful for flake inputs
#   where the name portion of the store path is always "source". Having a prefix
#   makes it easy to see what you made GC roots for.
# - The option to show a diff of your dev shell when it changes.
# - Roots are joined into a single derivation so you'll only have a single GC root
#   per project, or two if you enabled the dev shell GC root. This is reduces noise
#   in the full list of GC roots for your system (/nix/var/nix/gcroots/auto).

{
  lib,
  nixpkgs,
  utils,
  ...
}:
nixpkgs.callPackage (
  { nvd, coreutils }:
  let
    inherit (builtins) storeDir;
    inherit (lib)
      pipe
      escapeShellArg
      isStorePath
      attrsToList
      concatMap
      getExe
      mapAttrsToList
      optionalString
      removePrefix
      recursiveUpdate
      isList
      genericClosure
      getExe'
      concatStringsSep
      filter
      elem
      filterAttrs
      setAttrByPath
      optionals
      ;
    inherit (utils) linkFarm;

    handlers = {
      #       <spec> -> <store_path> | list[<spec>] | attrset[<prefix> -> <spec>]
      # <store_path> -> anything that can be coerced to a string that contains a store path
      #     <prefix> -> string
      #
      # All prefixes leading to a store_path will be prepended to it.
      path =
        let
          pathHelper =
            {
              prefixes ? [ ],
              spec,
            }:
            if isStorePath spec then
              [
                {
                  name = concatStringsSep "__" (prefixes ++ [ (removePrefix "${storeDir}/" spec) ]);
                  path = spec;
                }
              ]
            else if isList spec then
              concatMap (spec: pathHelper { inherit prefixes spec; }) spec
            else
              concatMap
                (
                  { name, value }:
                  pathHelper {
                    prefixes = prefixes ++ [ name ];
                    spec = value;
                  }
                )
                # The set returned from npins has `__functor`
                (attrsToList (removeAttrs spec [ "__functor" ]));
        in
        spec: pathHelper { inherit spec; };

      flake =
        let
          getInputsRecursive =
            {
              inputs,
              exclude ? [ ],
            }:
            let
              processInputs =
                let
                  removeExcluded = filterAttrs (_name: input: !(elem input exclude));

                  toClosureNodes =
                    {
                      parent ? null,
                      inputs,
                    }:
                    mapAttrsToList (
                      name: input:
                      input
                      // {
                        inherit name;
                        path = optionals (parent != null) (parent.path ++ [ parent.name ]);
                        # Used by `genericClosure` for equality checks
                        key = input.outPath;
                      }
                    ) inputs;
                in
                {
                  parent ? null,
                  inputs,
                }:
                pipe inputs [
                  removeExcluded
                  (inputs: toClosureNodes { inherit inputs parent; })
                ];
            in
            genericClosure {
              startSet = processInputs { inherit inputs; };
              operator =
                input:
                processInputs {
                  # Inputs with "flake = false" will not have inputs
                  inputs = input.inputs or { };
                  parent = input;
                };
            };
        in
        spec:
        pipe spec [
          getInputsRecursive
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath of any local flakes will not be a store path.
          # This includes the current flake and any inputs of type "path".
          (filter isStorePath)
          (map (input: setAttrByPath ([ "flake" ] ++ input.path ++ [ input.name ]) input))
          handlers.path
        ];
    };

    makeDerivation =
      {
        roots,
        snippetConfig,
      }:
      let
        derivation = linkFarm "gc-roots" roots;

        snippet =
          let
            nvdExe = getExe nvd;
            ln = getExe' coreutils "ln";
            mkdir = getExe' coreutils "mkdir";

            directory =
              if snippetConfig.directory ? eval then
                ''"${snippetConfig.directory.eval}"''
              else
                escapeShellArg snippetConfig.directory.text;

            devShellDiffSnippet = ''
              if [[ -e ${directory}/dev-shell-root ]]; then
                ${nvdExe} --color=never diff ${directory}/dev-shell-root "$new_shell"
              fi
            '';
          in
          # If the dev shell was bundled with `nix bundle`, then we shouldn't make
          # the GC root. We use `nix-store --query --hash` to see if the path we want
          # to make a root for is a valid store path. If it isn't, the shell was
          # probably bundled. Instead of making a root, we make a plain symlink. This
          # way, subsequent checks to see if the root is up to date will pass and we
          # won't have to keep running `nix-store --query --hash` which will be
          # slower than `[[ ... -ef ... ]]`.
          ''
            if [[ ! ${directory}/roots -ef ${derivation} ]]; then
              if
                type -P nix-store >/dev/null &&
                  nix-store --query --hash ${derivation} >/dev/null 2>&1
              then
                nix-store --add-root ${directory}/roots --realise ${derivation} >/dev/null
              else
                if [[ ! -e ${directory} ]]; then
                  ${mkdir} --parents ${directory}
                fi
                ${ln} --force --no-dereference --symbolic ${derivation} ${directory}/roots
              fi
            fi
          ''
          + optionalString snippetConfig.devShell.enable ''
            # Users can't pass in the shell derivation since that would cause
            # infinite recursion: To get the shell's outPath, we need the shellHook
            # which would include this snippet. And to get this snippet, we need the
            # shell's outPath. Instead, we make a separate GC root for the dev shell
            # at runtime. We can't always rely on `builtins.placeholder "out"`
            # pointing to the shell derivation because at least in the case of
            # numtide/devshell, the shellHook is not on the same derivation as the
            # shell. In those cases, we'll check certain environment variables that
            # should have the shell store path.
            new_shell=
            if [[ -n $DEVSHELL_DIR ]]; then
              new_shell="$DEVSHELL_DIR"
            else
              new_shell=${placeholder "out"}
            fi

            if [[ ! ${directory}/dev-shell-root -ef "$new_shell" ]]; then
              if
                type -P nix-store >/dev/null &&
                  nix-store --query --hash "$new_shell" >/dev/null 2>&1
              then
                ${optionalString snippetConfig.devShell.diff devShellDiffSnippet}
                nix-store --add-root ${directory}/dev-shell-root --realise "$new_shell" >/dev/null
              else
                if [[ ! -e ${directory} ]]; then
                  ${mkdir} --parents ${directory}
                fi
                ${ln} --force --no-dereference --symbolic "$new_shell" ${directory}/dev-shell-root
              fi
            fi
          '';
      in
      derivation // { inherit snippet; };
  in
  config:
  let
    # Set defaults
    snippetConfig = recursiveUpdate {
      devShell = {
        diff = true;
        enable = true;
      };
    } config.snippet;
  in
  pipe config.roots [
    attrsToList
    (concatMap ({ name, value }: handlers.${name} value))
    (roots: makeDerivation { inherit roots snippetConfig; })
  ]
) { }
