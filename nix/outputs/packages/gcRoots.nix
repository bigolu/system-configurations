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
  ...
}:
nixpkgs.callPackage (
  {
    nvd,
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
      recursiveUpdate
      isList
      genericClosure
      getExe'
      concatStringsSep
      filter
      elem
      filterAttrs
      sort
      lessThan
      ;

    handlers = {
      #       <spec> -> <store_path> | list[<spec>] | attrset[<prefix> -> <spec>]
      # <store_path> -> anything that can be coerced to a string that contains a store path
      #     <prefix> -> string
      #
      # All prefixes leading to a store_path will be used as a label for the path.
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
                  inherit prefixes;
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
                  # So we can compare inputs by their outPath instead of comparing
                  # the entire attrset.
                  excludeOutPaths = map (input: input.outPath) exclude;
                  removeExcluded = filterAttrs (_name: input: !(elem input.outPath excludeOutPaths));

                  toClosureNodes = mapAttrsToList (
                    name: input:
                    input
                    // {
                      inherit name;
                      # Used by `genericClosure` for equality checks
                      key = input.outPath;
                    }
                  );
                in
                inputs:
                pipe inputs [
                  removeExcluded
                  toClosureNodes
                ];
            in
            genericClosure {
              startSet = processInputs inputs;
              # Inputs with "flake = false" will not have inputs
              operator = input: processInputs (input.inputs or { });
            };
        in
        spec:
        pipe spec [
          getInputsRecursive
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath of any local flakes will not be a store path.
          # This includes the current flake and any inputs of type "path".
          (filter isStorePath)
          (map (input: {
            ${input.name} = input;
          }))
          (inputs: handlers.path { flake = inputs; })
        ];
    };

    makeDerivation =
      {
        roots,
        snippetConfig,
      }:
      let
        derivation = writeTextFile {
          name = "roots.txt";
          text = pipe roots [
            (map (
              { prefixes, path }: path + optionalString (prefixes != [ ]) " (${concatStringsSep "." prefixes})"
            ))
            (sort lessThan)
            (concatStringsSep "\n")
          ];
        };

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

            rootsPath = "${directory}/roots";
            devShellRootPath = "${directory}/dev-shell-root";

            devShellDiffSnippet = ''
              if [[ -e ${devShellRootPath} ]]; then
                ${nvdExe} --color=never diff ${devShellRootPath} "$new_shell"
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
            if [[ ! ${rootsPath} -ef ${derivation} ]]; then
              if
                type -P nix-store >/dev/null &&
                  nix-store --query --hash ${derivation} >/dev/null 2>&1
              then
                nix-store --add-root ${rootsPath} --realise ${derivation} >/dev/null
              else
                if [[ ! -e ${directory} ]]; then
                  ${mkdir} --parents ${directory}
                fi
                ${ln} --force --no-dereference --symbolic ${derivation} ${rootsPath}
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

            if [[ ! ${devShellRootPath} -ef "$new_shell" ]]; then
              if
                type -P nix-store >/dev/null &&
                  nix-store --query --hash "$new_shell" >/dev/null 2>&1
              then
                ${optionalString snippetConfig.devShell.diff devShellDiffSnippet}
                nix-store --add-root ${devShellRootPath} --realise "$new_shell" >/dev/null
              else
                if [[ ! -e ${directory} ]]; then
                  ${mkdir} --parents ${directory}
                fi
                ${ln} --force --no-dereference --symbolic "$new_shell" ${devShellRootPath}
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
