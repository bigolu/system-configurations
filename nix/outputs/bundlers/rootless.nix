{
  nixpkgs,
  inputs,
  utils,
  ...
}:
nixpkgs.callPackage (
  {
    lib,
    writeClosure,
    stdenv,
    buildGoApplication ? inputs.gomod2nix.outputs.buildGoApplication,
  }:
  drv:
  let
    inherit (builtins)
      pathExists
      baseNameOf
      concatStringsSep
      attrNames
      hasAttr
      ;
    inherit (lib)
      getName
      warn
      getExe'
      assertMsg
      ;

    makeRootlessProgram =
      {
        derivation,
        entrypoint,
        name,
      }:
      let
        inherit (stdenv) mkDerivation;

        gozipProjectRoot = utils.gitFilter ../../../gozip;

        gozip = buildGoApplication {
          pname = "gozip";
          version = "0.1";
          src = gozipProjectRoot;
          pwd = gozipProjectRoot;

          # Adding these tags so the gozip executable is linked statically.
          # More info: https://mt165.co.uk/blog/static-link-go/index.html
          tags = [
            "osusergo"
            "netgo"
          ];
        };
      in
      mkDerivation {
        inherit name;
        dontUnpack = true;
        nativeBuildInputs = [ gozip ];
        installPhase = ''
          # I want an empty directory to store the closure and entrypoint of
          # the input derivation. By default, the build directory contains
          # the file "env-vars" so I'll move into a different directory.
          mkdir closure
          cd closure

          readarray -t closure_store_paths <${writeClosure derivation}
          cp --recursive "''${closure_store_paths[@]}" ./
          cp ${entrypoint} entrypoint

          # So gozip can rewrite the store paths after extraction
          chmod -R +w .

          cp --dereference "$(type -P gozip)" $out
          chmod +w $out
          gozip -create $out *
        '';
      };

    getMainProgram =
      derivation:
      let
        assumedMainProgramBaseName =
          let
            packageDisplayName = derivation.meta.name or derivation.pname or derivation.name;
            assumption = getName derivation;
          in
          warn "rootless-bundler: Package ${packageDisplayName} does not have the meta.mainProgram attribute. Assuming you want '${assumption}'." assumption;

        mainProgramBaseName = derivation.meta.mainProgram or assumedMainProgramBaseName;
        mainProgramPath = getExe' derivation mainProgramBaseName;
        mainProgramExists = pathExists mainProgramPath;
      in
      assert assertMsg mainProgramExists "Main program ${mainProgramPath} does not exist";
      mainProgramPath;

    handlers = {
      app =
        drv:
        makeRootlessProgram {
          derivation = drv.program;
          entrypoint = drv.program;
          name = baseNameOf drv.program;
        };

      derivation =
        drv:
        makeRootlessProgram {
          derivation = drv;
          entrypoint = getMainProgram drv;
          name = drv.pname or drv.meta.name or drv.name;
        };
    };

    known-types = concatStringsSep ", " (attrNames handlers);
  in
  assert assertMsg (hasAttr drv.type handlers)
    "don't know how to make a bundle for type '${drv.type}'; only know ${known-types}";
  handlers.${drv.type} drv
) { }
