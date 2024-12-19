final: _prev:
{
  config,
  shell,
  init ? null,
}:
let
  inherit (final.stdenv) isLinux;
  inherit (final.lib) fileset escapeShellArg;

  # "C.UTF-8/UTF-8" is the locale that perl said wasn't supported so I added it
  # here. "en_US.UTF-8/UTF-8" is the default locale so I'm keeping it just in
  # case.
  locales = final.glibcLocales.override {
    allLocales = false;
    locales = [
      "en_US.UTF-8/UTF-8"
      "C.UTF-8/UTF-8"
    ];
  };

  bashPath = "${final.bash}/bin/bash";

  inherit (config) activationPackage;

  localeArchive =
    if isLinux then "export LOCALE_ARCHIVE=${locales}/lib/locale/locale-archive" else "";

  initSnippet = if init != null then "INIT_SNIPPET=${escapeShellArg init}" else "";

  bootstrap = final.resholve.mkDerivation {
    pname = "bootstrap-home-shell";
    version = "0.0.1";
    src = fileset.toSource {
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
        interpreter = bashPath;
        inputs = with final; [
          coreutils-full
          which
        ];
        execer = [
          "cannot:${final.coreutils-full}/bin/mktemp"
          "cannot:${final.coreutils-full}/bin/mkdir"
          "cannot:${final.coreutils-full}/bin/basename"
          "cannot:${final.coreutils-full}/bin/ln"
          "cannot:${final.coreutils-full}/bin/chmod"
          "cannot:${final.coreutils-full}/bin/cp"
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

  name = "shell";

in
(final.writeScriptBin name ''
  #!${bashPath}
  BASH_PATH=${bashPath}
  ACTIVATION_PACKAGE=${activationPackage}
  USER_SHELL=${escapeShellArg shell}
  ${localeArchive}
  ${initSnippet}
  source ${bootstrap}/bin/bootstrap
'')
// {
  meta.mainProgram = name;
}
