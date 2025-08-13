# TODO: I'd like to be able to create a GC root for devShells the way nix-direnv
# does, but there's no way to generate the derivation created by `nix print-dev-env`
# outside of the CLI[1]. If the GC root were made here, then I could also add logic
# for printing a diff of the devShell when the derivation changes using `nvd`. I
# think this (draft) pull request would address this[2].
#
# [1]: https://github.com/NixOS/nix/issues/7468
# [2]: https://github.com/NixOS/nixpkgs/pull/330822

{ lib, nixpkgs, ... }:
nixpkgs.callPackage (
  {
    writeTextFile,
    coreutils,
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
      getExe'
      mapAttrsToList
      fix
      ;

    handlers = {
      paths = id;
      derivations = map (derivation: "${derivation.name}: ${derivation.outPath}");

      npins =
        { pins }:
        pipe pins [
          (pins: removeAttrs pins [ "__functor" ])
          (mapAttrsToList (name: pin: "${name}: ${pin.outPath}"))
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
              destination = escapeShellArg hook.destination;
              ln = getExe' coreutils "ln";
              inherit (self) outPath;
            in
            ''
              if [[ -e ${destination} ]]; then
                if [[ ! ${destination} -ef ${outPath} ]]; then
                  ${ln} --force --no-dereference --symbolic ${outPath} ${destination}
                fi
              else
                nix build --out-link ${destination} ${outPath}
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

    getGcRoots =
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
      getGcRoots {
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
