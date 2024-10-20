{ inputs, ... }:
final: prev:
let
  inherit (final.stdenv) isLinux;

  catp = final.stdenv.mkDerivation {
    pname = "catp";
    version = "0.2.0";
    src = prev.fetchzip {
      url = "https://github.com/rapiz1/catp/releases/download/v0.2.0/catp-x86_64-unknown-linux-gnu.zip";
      sha256 = "sha256-U7h/Ecm+8oXy8Zr+Rq25eSiZw/2/GuUCFvnCtuc7pT8=";
    };
    installPhase = ''
      mkdir -p $out/bin
      cp $src/catp $out/bin/
    '';
    meta = {
      platforms = with inputs.flake-utils.lib.system; [
        x86_64-linux
      ];
    };
  };

  config-file-validator = final.stdenv.mkDerivation {
    pname = "config-file-validator";
    version = "1.7.1";
    src = prev.fetchzip {
      url = "https://github.com/Boeing/config-file-validator/releases/download/v1.7.1/validator-v1.7.1-${
        if isLinux then "linux" else "darwin"
      }-amd64.tar.gz";
      sha256 =
        if isLinux then
          "sha256-0GE2CBi4JPgDtt2ifYI6QeZ/cGz0lDgyTIT28tCC5Kk="
        else
          "sha256-Bj84jL1YwBbgDM2Z9G1uIXo/YtDkOjrFe+atwXsISGE=";
      stripRoot = false;
    };
    installPhase = ''
      mkdir -p $out/bin
      cp $src/validator $out/bin/
    '';
    meta = {
      platforms = with inputs.flake-utils.lib.system; [
        x86_64-linux
        x86_64-darwin
      ];
    };
  };
in
{
  inherit catp config-file-validator;
}
