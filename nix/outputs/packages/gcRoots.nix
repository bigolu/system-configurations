{
  lib,
  nixpkgs,
  ...
}:
nixpkgs.callPackage (
  {
    writeTextFile,
    nvd,
  }:
  let
    inherit (lib)
      concatStringsSep
      pipe
      escapeShellArg
      filter
      isStorePath
      genericClosure
      attrsToList
      concatMap
      id
      getExe
      mapAttrsToList
      fix
      optionalString
      optionals
      isBool
      ;

    handlers = {
      paths = id;
      derivations = map (derivation: "${derivation.name}: ${derivation}");

      devShell =
        shellOrBool:
        if isBool shellOrBool then
          optionals shellOrBool [ "(Created in shellHook)" ]
        else
          [ "${shellOrBool.name}: ${shellOrBool}" ];

      npins =
        { pins }:
        pipe pins [
          (pins: removeAttrs pins [ "__functor" ])
          (mapAttrsToList (name: pin: "${name}: ${pin}"))
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
        { inputs }:
        pipe inputs [
          getInputsRecursive
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath of any local flakes will not be a store path.
          # This includes the current flake and any inputs of type "path".
          (filter isStorePath)
          (map (input: "${input.name}: ${input}"))
        ];
    };

    makeGcRootDerivation =
      {
        gcRootsString,
        hook,
        roots,
      }:
      fix (
        self:
        let
          shellHook =
            let
              directory =
                if hook.directory ? eval then ''"${hook.directory.eval}"'' else escapeShellArg hook.directory.text;
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
            + optionalString roots.devShell ''
              if [[ -z ''${IN_NIX_BUNDLE:-} ]]; then
                # Users can't pass in the shell derivation since that would cause
                # infinite recursion: To get the shell's outPath, we'd need the
                # shellHook which would include this snippet. And to get this snippet,
                # we'd need the shell's outPath. Instead, we get the shells outPath at
                # runtime and make a separate GC root for it.
                new_shell=
                if [[ -n $DEVSHELL_DIR ]]; then
                  new_shell="$DEVSHELL_DIR"
                fi

                if [[ -n $new_shell && ! ${directory}/dev-shell-root -ef "$new_shell" ]]; then
                  ${optionalString hook.devShellDiff devShellDiffSnippet}
                  nix build --out-link ${directory}/dev-shell-root "$new_shell"
                fi
              fi
            '';
        in
        writeTextFile {
          name = "gc-roots";
          text = gcRootsString;
          passthru = { inherit shellHook; };
        }
      );

    makeGcRootSectionLines =
      let
        addHeaderAndSeparator = { gcRoots, type }: [ "roots for ${type}:" ] ++ gcRoots ++ [ "" ];
      in
      { type, config }:
      let
        gcRoots = handlers.${type} config;
      in
      optionals (gcRoots != [ ]) addHeaderAndSeparator { inherit gcRoots type; };
  in
  config:
  let
    # Set sefaults
    hook = {
      devShellDiff = true;
    }
    // config.hook;
    roots = {
      devShell = true;
    }
    // config.roots;
  in
  pipe roots [
    attrsToList
    (concatMap (
      { name, value }:
      makeGcRootSectionLines {
        type = name;
        config = value;
      }
    ))
    (concatStringsSep "\n")
    # Combine them into a single derivation to avoid having multiple GC roots for a
    # single project.
    (gcRootsString: makeGcRootDerivation { inherit gcRootsString hook roots; })
  ]
) { }
