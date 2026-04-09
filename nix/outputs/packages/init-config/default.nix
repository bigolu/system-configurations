{ nixpkgs, name, ... }:
nixpkgs.callPackage (
  {
    lib,
    resholve,
    bash,
    git,
    direnv,
    perl,
    coreutils,
    writeShellApplication,
  }:
  let
    inherit (lib) getExe getExe';

    script = resholve.mkDerivation {
      pname = name;
      version = "0.0.1";
      src = ./init-config.bash;
      meta.mainProgram = name;
      dontUnpack = true;
      installPhase = ''
        install -D $src $out/bin/${name}
      '';
      solutions.default = {
        scripts = [ "bin/${name}" ];
        interpreter = "${bash}/bin/bash";
        inputs = [
          git
          direnv
          perl
          coreutils
        ];
        execer = [
          "cannot:${getExe git}"
          "cannot:${getExe direnv}"
          "cannot:${getExe' perl "shasum"}"
        ];
        keep = {
          "/bin/bash" = true;
        };
        fake.external = [
          "mise"
          "curl"
        ];
      };
    };
  in
  writeShellApplication {
    name = "run-as-admin";
    # direnv plugins assume these are on the PATH
    runtimeInputs = [
      direnv
      bash
      coreutils
    ];
    text = ''
      ${getExe script}
    '';
  }
) { }
