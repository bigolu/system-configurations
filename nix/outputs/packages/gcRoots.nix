{ lib, nixpkgs, ... }:
nixpkgs.callPackage (
  {
    writeTextFile,
    coreutils,
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
      getExe'
      mapAttrsToList
      fix
      optionalString
      ;

    handlers = {
      paths = id;
      derivations = map (derivation: "${derivation.name}: ${derivation}");
      devShell = shell: [ "${nvd.name}: ${shell}" ];

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
          (map (input: "${input.name}: ${input.outPath}"))
        ];
    };

    makeGcRootDerivation =
      { gcRootsString, hook, roots }:
      fix (
        self:
        let
          shellHook =
            let
              directory = escapeShellArg hook.directory;
              ln = getExe' coreutils "ln";
              nvdExe = getExe nvd;
              inherit (self) outPath;
              # inherit (roots) devShell;
              devShell = nvd.outPath;
              # outPath = nvd.outPath;
              #
              #
              # if [[ ! ${directory}/root-list -ef ${outPath} ]]; then
              #   nix build --out-link ${directory}/root-list ${outPath}
              # fi
            in
            ''
              # PERF: We could just always run `nix`, but `-ef` is faster. The
              # `shellHook` should be fast since people often run it through
              # `direnv`.
              : ${builtins.unsafeDiscardStringContext (escapeShellArg "")}
            ''
            + optionalString (hook.devShellDiff or false) ''
              if [[ ! -e ${directory}/dev-shell ]]; then
                # Use force to avoid race condition with other instances of the
                # direnv environment e.g. IDE.
                ${ln} --force --no-dereference --symbolic ${devShell} ${directory}/dev-shell
              elif [[ ! ${directory}/dev-shell -ef ${devShell} ]]; then
                ${nvdExe} --color=never diff ${directory}/dev-shell ${devShell}
                # Use force to avoid race condition with other instances of the
                # direnv environment e.g. IDE.
                ${ln} --force --no-dereference --symbolic ${devShell} ${directory}/dev-shell
              fi
            '';
        in
        { inherit shellHook; }
      );

    addHeaderAndSeparator = { gcRoots, type }: [ "roots for ${type}:" ] ++ gcRoots ++ [ "" ];

    getGcRootSection =
      { type, config }:
      addHeaderAndSeparator {
        gcRoots = handlers.${type} config;
        inherit type;
      };
  in
  {
    hook,
    roots,
  }:
  pipe roots [
    attrsToList
    (concatMap (
      { name, value }:
      getGcRootSection {
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
