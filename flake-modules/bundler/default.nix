{
  flake-parts-lib,
  inputs,
  lib,
  ...
}:
let
  bundlerOption =
    let
      inherit (flake-parts-lib) mkTransposedPerSystemModule;
      inherit (lib) mkOption types;
    in
    mkTransposedPerSystemModule {
      name = "bundlers";
      option = mkOption {
        type = types.anything;
        default = { };
      };
      file = ./default.nix;
    };
in
bundlerOption
// {
  config.perSystem =
    {
      lib,
      system,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) optionalAttrs;
      makeExecutable =
        {
          derivation,
          entrypoint,
          name,
        }:
        let
          nameWithArch = "${name}-${system}";
          goPkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.gomod2nix.overlays.default
            ];
          };
          gozip = goPkgs.buildGoApplication {
            pname = "gozip";
            version = "0.1";
            src = ./gozip;
            pwd = ./gozip;
            modules = ./gozip/gomod2nix.toml;
            # Adding these tags so the gozip executable is built statically.
            # More info: https://mt165.co.uk/blog/static-link-go
            tags = [
              "osusergo"
              "netgo"
            ];
          };
        in
        pkgs.stdenv.mkDerivation {
          pname = nameWithArch;
          name = nameWithArch;
          dontUnpack = true;
          buildInputs = [ gozip ];
          installPhase = ''
            mkdir deps
            cp --recursive $(cat ${pkgs.writeClosure derivation}) ./deps/
            chmod -R 777 ./deps
            cd ./deps
            cp ${entrypoint} entrypoint
            chmod 777 entrypoint
            cp --dereference "$(${pkgs.which}/bin/which gozip)" $out
            chmod +w $out
            gozip -create $out ./*
          '';
        };

      defaultBundler =
        let
          program =
            derivation:
            let
              assumedMainProgramBaseName =
                let
                  packageDisplayName = derivation.meta.name or derivation.pname or derivation.name;
                  assumption = lib.getName derivation;
                in
                lib.warn "rootless-bundler: Package ${packageDisplayName} does not have the meta.mainProgram attribute. Assuming you want '${assumption}'." assumption;

              mainProgramBaseName = derivation.meta.mainProgram or assumedMainProgramBaseName;
              mainProgramPath = lib.getExe' derivation mainProgramBaseName;
              mainProgramExists = builtins.pathExists mainProgramPath;
            in
            assert pkgs.lib.assertMsg mainProgramExists "Main program ${mainProgramPath} does not exist";
            mainProgramPath;

          handler = {
            app =
              drv:
              makeExecutable {
                derivation = drv.program;
                entrypoint = drv.program;
                name = builtins.baseNameOf drv.program;
              };

            derivation =
              drv:
              makeExecutable {
                derivation = drv;
                entrypoint = program drv;
                inherit (drv) name;
              };
          };

          known-types = builtins.concatStringsSep ", " (builtins.attrNames handler);
        in
        drv:
        assert pkgs.lib.assertMsg (
          handler ? ${drv.type}
        ) "don't know how to make a bundle for type '${drv.type}'; only know ${known-types}";
        handler.${drv.type} drv;

      bundlerOutput = {
        bundlers.default = defaultBundler;
      };

      supportedSystems = with inputs.flake-utils.lib.system; [
        x86_64-linux
        x86_64-darwin
      ];

      isSupportedSystem = builtins.elem system supportedSystems;
    in
    optionalAttrs isSupportedSystem bundlerOutput;
}
