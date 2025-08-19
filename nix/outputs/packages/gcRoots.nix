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
      isList
      mergeAttrsList
      optionalAttrs
      getExe'
      concatMapStrings
      ;
    inherit (utils) linkFarm;

    removeStoreDir = removePrefix "${storeDir}/";

    handlers = {
      path =
        let
          path' =
            {
              prefixes ? [ ],
              config,
            }:
            if isStorePath config then
              [
                {
                  name = (concatMapStrings (prefix: "${prefix}-") prefixes) + (removeStoreDir config);
                  path = config;
                }
              ]
            else if isList config then
              concatMap (
                config':
                path' {
                  inherit prefixes;
                  config = config';
                }
              ) config
            else
              concatMap
                (
                  { name, value }:
                  path' {
                    prefixes = prefixes ++ [ name ];
                    config = value;
                  }
                )
                # The set returned from npins has `__functor`
                (attrsToList (removeAttrs config [ "__functor" ]));
        in
        config: path' { inherit config; };

      flake =
        let
          getInputsRecursive =
            let
              getInputsRecursive' =
                {
                  inputs,
                  seen ? { },
                }:
                let
                  unseen = filterAttrs (name: _input: !seen ? name) inputs;
                  seenAndUnseen = seen // unseen;
                  inputsFromUnseen = mapAttrsToList (
                    _name: input:
                    # Inputs with "flake = false" will not have inputs
                    optionalAttrs (input ? inputs) (getInputsRecursive' {
                      inherit (input) inputs;
                      seen = seenAndUnseen;
                    })
                  ) unseen;
                in
                mergeAttrsList ([ seenAndUnseen ] ++ inputsFromUnseen);
            in
            inputs: getInputsRecursive' { inherit inputs; };
        in
        { inputs }:
        pipe inputs [
          getInputsRecursive
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath of any local flakes will not be a store path.
          # This includes the current flake and any inputs of type "path".
          (filterAttrs (_name: isStorePath))
          (inputs: handlers.path { flake = inputs; })
        ];
    };

    makeDerivation =
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
    (roots: makeDerivation { inherit roots snippetConfig; })
  ]
) { }
