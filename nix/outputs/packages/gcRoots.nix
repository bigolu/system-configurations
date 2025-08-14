# TODO: I'd like to be able to create a GC root for devShells the way nix-direnv
# does, but there's no way to generate the derivation created by `nix print-dev-env`
# outside of the CLI[1]. I tried to use the derivation for the devShell, but that
# didn't work since `placeholder "out"` is set to the directory of the dev
# environment. This is because we are technically in an environment for building the
# devShell. If the GC root were made here, then I could also add logic for printing a
# diff of the devShell when the derivation changes using `nvd`. I think this pull
# request would address this[2].
#
# [1]: https://github.com/NixOS/nix/issues/7468
# [2]: https://github.com/NixOS/nixpkgs/pull/330822

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
      devShell = _: [ (placeholder "out") ];

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
      { gcRootsString, hook }:
      fix (
        self:
        let
          shellHook =
            let
              directory = escapeShellArg hook.directory;
              ln = getExe' coreutils "ln";
              mkdir = getExe' coreutils "mkdir";
              nvdExe = getExe nvd;
              inherit (self) outPath;
              devShell = placeholder "out";
            in
            ''
              # PERF: We could just always run `mkdir` but `-d` is faster.
              # The `shellHook` should be fast since people often run it through
              # `direnv`.
              if [[ ! -d ${directory} ]]; then
                # Use `-p` to avoid race condition with other instances of the
                # direnv environment e.g. IDE.
                ${mkdir} -p ${directory}
              fi

              # PERF: We could just always run `nix`/`ln`, but `-e`/`-ef` is faster.
              # The `shellHook` should be fast since people often run it through
              # `direnv`.
              if [[ -e ${directory}/root-list ]]; then
                if [[ ! ${directory}/root-list -ef ${outPath} ]]; then
                  ${ln} --force --no-dereference --symbolic ${outPath} ${directory}/root-list
                fi
              else
                nix build --out-link ${directory}/root-list ${outPath}
              fi
            ''
            + optionalString (hook.devShellDiff or false) ''
              if [[ ! -e ${directory}/dev-shell ]]; then
                # Use force to avoid race condition with other instances of the
                # direnv environment e.g. IDE.
                ${ln} --force --no-dereference --symbolic ${devShell} ${directory}/dev-shell
              else
                if [[ ! ${devShell} -ef ${directory}/dev-shell ]]; then
                  ${nvdExe} --color=never diff ${directory}/dev-shell ${devShell}
                  ${ln} --force --no-dereference --symbolic ${devShell} ${directory}/dev-shell
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
    (gcRootsString: makeGcRootDerivation { inherit gcRootsString hook; })
  ]
) { }
