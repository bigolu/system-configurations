{
  inputs,
  pkgs,
  self,
  system,
  ...
}:
let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv) isLinux;

  name = "shell";

  # "C.UTF-8/UTF-8" is the locale that perl said wasn't supported so I added it here.
  # "en_US.UTF-8/UTF-8" is the default locale so I'm keeping it just in case.
  locales = pkgs.glibcLocales.override {
    allLocales = false;
    locales = [
      "en_US.UTF-8/UTF-8"
      "C.UTF-8/UTF-8"
    ];
  };

  bashPath = "${pkgs.bash}/bin/bash";

  activationPackage = import ./home-manager-package.nix {
    inherit
      self
      inputs
      pkgs
      system
      ;
  };

  localeArchive =
    if isLinux then "export LOCALE_ARCHIVE=${locales}/lib/locale/locale-archive" else "";

  bootstrap = pkgs.resholve.mkDerivation {
    pname = "bootstrap";
    version = "0.0.1";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = ./bootstrap.bash;
    };
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      install -D bootstrap.bash $out/bin/bootstrap
    '';
    solutions = {
      default = {
        scripts = [ "bin/bootstrap" ];
        interpreter = "${pkgs.bash}/bin/bash";
        inputs = with pkgs; [
          coreutils-full
          which
        ];
        execer = [
          "cannot:${pkgs.coreutils-full}/bin/mktemp"
          "cannot:${pkgs.coreutils-full}/bin/mkdir"
          "cannot:${pkgs.coreutils-full}/bin/basename"
          "cannot:${pkgs.coreutils-full}/bin/ln"
          "cannot:${pkgs.coreutils-full}/bin/chmod"
          "cannot:${pkgs.coreutils-full}/bin/cp"
        ];
        keep = {
          "$SHELL" = true;
        };
        fake = {
          external = [ "bat" ];
        };
      };
    };
  };
in
(pkgs.writeScriptBin name ''
  #!${bashPath}
  BASH_PATH=${bashPath}
  ACTIVATION_PACKAGE=${activationPackage}
  ${localeArchive}
  source ${bootstrap}/bin/bootstrap
'')
// {
  meta.mainProgram = name;
}
