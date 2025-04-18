final: _prev:
{
  homeConfig,
  shell,
  activation ? [ ],
}:
let
  inherit (builtins) attrValues catAttrs;
  inherit (final.stdenv) isLinux;
  inherit (final.lib)
    fileset
    escapeShellArg
    getAttrs
    concatStringsSep
    pipe
    ;

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

  inherit (homeConfig) activationPackage;

  localeArchive =
    if isLinux then "export LOCALE_ARCHIVE=${locales}/lib/locale/locale-archive" else "";

  activationSnippet = pipe activation [
    (activation: getAttrs activation homeConfig.config.home.activation)
    attrValues
    (catAttrs "data")
    (concatStringsSep "\n")
    escapeShellArg
    (snippet: "INIT_SNIPPET=${snippet}")
  ];

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
          coreutils
          which
        ];
        execer = [
          "cannot:${final.coreutils}/bin/mktemp"
          "cannot:${final.coreutils}/bin/mkdir"
          "cannot:${final.coreutils}/bin/basename"
          "cannot:${final.coreutils}/bin/ln"
          "cannot:${final.coreutils}/bin/chmod"
          "cannot:${final.coreutils}/bin/cp"
        ];
        keep = {
          "$SHELL" = true;
          "$BASH_PATH" = true;
        };
      };
    };
  };

  user = homeConfig.config.home.username;
  programName = "${user}-shell";
in
(final.writeScriptBin programName ''
  #!${bashPath}
  BASH_PATH=${bashPath}
  ACTIVATION_PACKAGE=${activationPackage}
  USER_SHELL=${escapeShellArg shell}
  ${localeArchive}
  ${activationSnippet}
  source ${bootstrap}/bin/bootstrap
'')
// {
  meta.mainProgram = programName;
}
