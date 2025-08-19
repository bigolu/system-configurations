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
  { nvd, coreutils }:
  let
    inherit (builtins) storeDir;
    inherit (lib)
      pipe
      escapeShellArg
      filterAttrs
      isStorePath
      attrsToList
      concatMap
      getExe
      mapAttrsToList
      fix
      optionalString
      removePrefix
      recursiveUpdate
      any
      attrValues
      isList
      mergeAttrsList
      optionalAttrs
      getExe'
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
        if any isStorePath (attrValues config) then
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
            {
              inputs,
              seen ? { },
            }:
            let
              unseen = filterAttrs (name: _input: !seen ? name) inputs;
              newSeen = seen // unseen;

              unseenFromUnseen = mapAttrsToList (
                _name: input:
                # Inputs with "flake = false" will not have inputs
                optionalAttrs (input ? inputs) (getInputsRecursive {
                  inherit (input) inputs;
                  seen = newSeen;
                })
              ) unseen;
            in
            mergeAttrsList ([ newSeen ] ++ unseenFromUnseen);
        in
        { inputs }:
        pipe inputs [
          (inputs: getInputsRecursive { inherit inputs; })
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath of any local flakes will not be a store path.
          # This includes the current flake and any inputs of type "path".
          (filterAttrs (_name: isStorePath))
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
            # the GC root. We use `nix-store --query --hash` to see if the path we
            # want to make a root for is a valid store path. If it isn't, the shell
            # was probably bundled. Instead of making a root, we make a plain
            # symlink. This way, subsequent checks to see if the root is up to date
            # will pass and we won't have to keep running `nix-store --query --hash`
            # which will be slower than `[[ ... -ef ... ]]`.
            ''
              if [[ ! ${directory}/roots -ef ${self} ]]; then
                if
                  type -P nix-store >/dev/null &&
                    nix-store --query --hash ${self} >/dev/null 2>&1
                then
                  nix-store --add-root ${directory}/roots --realise ${self} >/dev/null
                else
                  if [[ ! -e ${directory} ]]; then
                    ${mkdir} --parents ${directory}
                  fi
                  ${ln} --force --no-dereference --symbolic ${self} ${directory}/roots
                fi
              fi
            ''
            + optionalString snippetConfig.devShell.enable ''
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
        (linkFarm "gc-roots" roots) // { inherit snippet; }
      );
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
    # Combine them into a single derivation so each project only has one GC root, or
    # two if they enabled the dev shell GC root.
    (roots: makeRootsDerivation { inherit roots snippetConfig; })
  ]
) { }
