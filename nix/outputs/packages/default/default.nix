{ pkgs, ... }:
pkgs.callPackage (
  {
    lib,
    resholve,
    bash,
    git,
    direnv,
    coreutils,
    symlinkJoin,
    makeWrapper,
  }:
  let
    inherit (lib) getExe;

    script = resholve.mkDerivation rec {
      pname = "init-config";
      version = "0.1.0";
      src = ./init-config.bash;
      meta.mainProgram = pname;
      dontUnpack = true;
      installPhase = ''
        install -D $src $out/bin/${pname}
      '';
      solutions.default = {
        scripts = [ "bin/${pname}" ];
        interpreter = "${bash}/bin/bash";
        inputs = [
          git
          direnv
        ];
        execer = [
          "cannot:${getExe git}"
          "cannot:${getExe direnv}"
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
  symlinkJoin {
    inherit (script) pname version meta;
    paths = [ script ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      # direnv plugins assume these are on the PATH
      wrapProgram $out/bin/init-config \
        --prefix PATH : ${direnv}/bin \
        --prefix PATH : ${bash}/bin \
        --prefix PATH : ${coreutils}/bin
    '';
  }
) { }
