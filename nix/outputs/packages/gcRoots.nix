# There's an issue for having flakes retain a reference to their inputs[1].
#
# [1]: https://github.com/NixOS/nix/issues/6895#issuecomment-2475461113

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
      removePrefix
      recursiveUpdate
      any
      isDerivation
      attrValues
      isList
      nameValuePair
      listToAttrs
      ;
    inherit (utils) linkFarm;

    removeStoreDir = removePrefix "${storeDir}/";

    handlers = {
      unnamed =
        let
          getPathsForGroup =
            group:
            map (path: {
              name = (optionalString (group ? name) "${group.name}-") + (removeStoreDir path);
              inherit path;
            }) group.paths;
        in
        config:
        if isList config then
          getPathsForGroup { paths = config; }
        else
          concatMap (
            { name, value }:
            getPathsForGroup {
              inherit name;
              paths = value;
            }
          ) (attrsToList config);

      named =
        let
          getPathsForGroup =
            group:
            pipe group.paths [
              # The set returned from npins has `__functor`
              (paths: removeAttrs paths [ "__functor" ])
              (mapAttrsToList (
                name: path: {
                  name = (optionalString (group ? name) "${group.name}-") + "${name}-${removeStoreDir path}";
                  inherit path;
                }
              ))
            ];
        in
        config:
        if any (value: isStorePath value || isDerivation value) (attrValues config) then
          getPathsForGroup { paths = config; }
        else
          concatMap (
            { name, value }:
            getPathsForGroup {
              inherit name;
              paths = value;
            }
          ) (attrsToList config);

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
        { inputs }:
        pipe inputs [
          getInputsRecursive
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath of any local flakes will not be a store path.
          # This includes the current flake and any inputs of type "path".
          (filter isStorePath)
          (map (input: nameValuePair input.name input))
          listToAttrs
          (inputs: handlers.named { flake = inputs; })
        ];
    };

    makeRootsDerivation =
      {
        roots,
        snippetConfig,
      }:
      fix (
        self:
        let
          snippet =
            let
              nvdExe = getExe nvd;

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
            ''
              if [[ -z ''${IN_NIX_BUNDLE:-} ]]; then
                if [[ ! ${directory}/roots -ef ${self} ]]; then
                  nix build --out-link ${directory}/roots ${self}
                fi
              fi
            ''
            + optionalString snippetConfig.devShell.enable ''
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
                  ${optionalString snippetConfig.devShell.diff devShellDiffSnippet}
                  nix build --out-link ${directory}/dev-shell-root "$new_shell"
                fi
              fi
            '';
        in
        (linkFarm "gc-roots" roots) // { inherit snippet; }
      );
  in
  config:
  let
    # Set sefaults
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
    # Combine them into a single derivation so each project only has one GC root, or
    # two if they enabled the dev shell GC root.
    (roots: makeRootsDerivation { inherit roots snippetConfig; })
  ]
) { }
