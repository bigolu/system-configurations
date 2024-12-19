{
  flake-parts-lib,
  lib,
  utils,
  ...
}:
let
  inherit (builtins)
    pathExists
    baseNameOf
    concatStringsSep
    attrNames
    ;
  inherit (lib)
    recursiveUpdate
    getName
    warn
    getExe'
    assertMsg
    mkOption
    types
    ;
  inherit (utils) projectRoot;
  inherit (flake-parts-lib) mkTransposedPerSystemModule;

  bundlerOption = mkTransposedPerSystemModule {
    name = "bundlers";
    option = mkOption {
      type = types.anything;
      default = { };
    };
    file = ./bundlers.nix;
  };

  bundlers = {
    config.perSystem =
      { pkgs, ... }:
      let
        makeRootlessProgram =
          {
            derivation,
            entrypoint,
            name,
          }:
          let
            inherit (pkgs) buildGoApplication stdenv writeClosure;

            gozipProjectRoot = projectRoot + /gozip;

            gozip = buildGoApplication {
              pname = "gozip";
              version = "0.1";
              src = gozipProjectRoot;
              pwd = gozipProjectRoot;

              # Adding these tags so the gozip executable is linked statically.
              # More info: https://mt165.co.uk/blog/static-link-go
              tags = [
                "osusergo"
                "netgo"
              ];
            };
          in
          stdenv.mkDerivation {
            pname = name;
            version = derivation.version or "0.0.1";
            dontUnpack = true;
            buildInputs = [
              gozip
              pkgs.which
            ];
            installPhase = ''
              mkdir deps
              cp --recursive $(cat ${writeClosure derivation}) ./deps/
              cp ${entrypoint} ./deps/entrypoint
              chmod -R 777 ./deps

              cp --dereference "$(which gozip)" $out
              chmod +w $out

              cd deps
              gozip -create $out ./*
            '';
          };

        rootlessBundler =
          let
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

            handler = {
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
                  name = drv.meta.name or drv.pname or drv.name;
                };
            };

            known-types = concatStringsSep ", " (attrNames handler);
          in
          drv:
          assert assertMsg (
            handler ? ${drv.type}
          ) "don't know how to make a bundle for type '${drv.type}'; only know ${known-types}";
          handler.${drv.type} drv;
      in
      {
        bundlers.default = rootlessBundler;
        bundlers.rootless = rootlessBundler;
      };
  };
in
recursiveUpdate bundlerOption bundlers
