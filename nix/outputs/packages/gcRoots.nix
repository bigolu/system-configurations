{
  lib,
  nixpkgs,
  utils,
  ...
}:
nixpkgs.callPackage (
  { nvd }:
  let
    inherit (builtins) storeDir;
    inherit (lib)
      pipe
      escapeShellArg
      filter
      isStorePath
      genericClosure
      attrsToList
      concatMap
      getExe
      mapAttrsToList
      fix
      optionalString
      isBool
      removePrefix
      ;
    inherit (utils) linkFarm;

    removeStoreDir = removePrefix "${storeDir}/";

    handlers = {
      paths =
        type:
        map (path: {
          name = "${type}-${removeStoreDir path}";
          inherit path;
        });

      derivations =
        type:
        map (derivation: {
          name = "${type}-${removeStoreDir derivation}";
          path = derivation;
        });

      devShell =
        type: shellOrBool:
        if isBool shellOrBool then
          [ ]
        else
          [
            {
              name = "${type}-${removeStoreDir shellOrBool}";
              path = shellOrBool;
            }
          ];

      npins =
        type:
        { pins }:
        pipe pins [
          (pins: removeAttrs pins [ "__functor" ])
          (mapAttrsToList (
            name: pin: {
              name = "${type}-${name}-${removeStoreDir pin}";
              path = pin;
            }
          ))
        ];

      flake =
        let
          getInputsRecursive =
            let
              toClosureNode =
                name: input:
                input
                // {
                  # Used by `genericClosure` for equality checks
                  key = input.outPath;
                  # The inputs will be mapped from a set to a list, but we'll need the
                  # name later so we'll add it to the input.
                  inherit name;
                };

              toClosureNodes = mapAttrsToList toClosureNode;
            in
            directInputs:
            genericClosure {
              startSet = toClosureNodes directInputs;
              # Inputs with "flake = false" will not have inputs
              operator = input: toClosureNodes (input.inputs or { });
            };
        in
        type:
        { inputs }:
        pipe inputs [
          getInputsRecursive
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath of any local flakes will not be a store path.
          # This includes the current flake and any inputs of type "path".
          (filter isStorePath)
          (map (input: {
            name = "${type}-${input.name}-${removeStoreDir input}";
            path = input;
          }))
        ];
    };

    makeRootsDerivation =
      {
        roots,
        config,
      }:
      fix (
        self:
        let
          hookConfig = config.hook;
          rootsConfig = config.roots;

          shellHook =
            let
              directory =
                if hookConfig.directory ? eval then
                  ''"${hookConfig.directory.eval}"''
                else
                  escapeShellArg hookConfig.directory.text;
              nvdExe = getExe nvd;
              devShellDiffSnippet = ''
                if [[ -e ${directory}/dev-shell-root ]]; then
                  ${nvdExe} --color=never diff ${directory}/dev-shell-root "$new_shell"
                fi
              '';
            in
            ''
              if [[ -z ''${IN_NIX_BUNDLE:-} ]]; then
                if [[ ! ${directory}/roots -ef ${self} ]]; then
                  nix build --out-link ${directory}/roots ${self}
                fi
              fi
            ''
            + optionalString rootsConfig.devShell ''
              if [[ -z ''${IN_NIX_BUNDLE:-} ]]; then
                # Users can't pass in the shell derivation since that would cause
                # infinite recursion: To get the shell's outPath, we need the
                # shellHook which would include this snippet. And to get this
                # snippet, we need the shell's outPath. Instead, we get the shell's
                # outPath at runtime and make a separate GC root for it.
                new_shell=
                if [[ -n $DEVSHELL_DIR ]]; then
                  new_shell="$DEVSHELL_DIR"
                fi

                if [[ -n $new_shell && ! ${directory}/dev-shell-root -ef "$new_shell" ]]; then
                  ${optionalString hookConfig.devShellDiff devShellDiffSnippet}
                  nix build --out-link ${directory}/dev-shell-root "$new_shell"
                fi
              fi
            '';
        in
        (linkFarm "gc-roots" roots) // { inherit shellHook; }
      );
  in
  configWithoutDefaults:
  let
    # Set sefaults
    config = {
      hook = {
        devShellDiff = true;
      }
      // configWithoutDefaults.hook;

      roots = {
        devShell = true;
      }
      // configWithoutDefaults.roots;
    };
  in
  pipe config.roots [
    attrsToList
    (concatMap ({ name, value }: handlers.${name} name value))
    # Combine them into a single derivation so each project only has one GC root, or
    # two if they enabled the dev shell GC root.
    (roots: makeRootsDerivation { inherit config roots; })
  ]
) { }
