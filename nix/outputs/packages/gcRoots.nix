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
  in
  {
    hook,
    roots,
  }:
  pipe roots [
    attrsToList
    (concatMap ({ name, value }: [ "roots for ${name}:" ] ++ (handlers.${name} value) ++ [ "" ]))
    (concatStringsSep "\n")

    # Combine them into a single derivation to avoid adding multiple GC roots for a
    # single project.
    (
      text:
      fix (
        self:
        writeTextFile {
          name = "gc-roots";
          inherit text;
          passthru.shellHook =
            let
              escapedDestination = escapeShellArg hook.destination;
              ln = getExe' coreutils "ln";
            in
            ''
              if [[ -e ${escapedDestination} ]]; then
                if [[ ! ${self.outPath} -ef ${escapedDestination} ]]; then
                  ${ln} --force --no-dereference --symbolic ${self.outPath} ${escapedDestination}
                fi
              else
                nix build --out-link ${escapedDestination} ${self.outPath}
              fi
            '';
        }
      )
    )
  ]
) { }
