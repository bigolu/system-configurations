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

  bashPath = "${final.bash}/bin/bash";
  inherit (homeConfig) activationPackage;

  initSnippet =
    let
      # Nix recommends setting the LOCALE_ARCHIVE environment variable for non-NixOS
      # Linux distributions[1].
      #
      # [1]: https://nixos.wiki/wiki/Locales
      localeSnippet =
        let
          # The full set of locales is pretty big (~220MB) so I'll only include the
          # one that will be used.
          locales = final.glibcLocales.override {
            allLocales = false;
            locales = [ "en_US.UTF-8/UTF-8" ];
          };
        in
        if isLinux then
          ''
            if [[ -z ''${LOCALE_ARCHIVE:-} ]]; then
              export LOCALE_ARCHIVE=${locales}/lib/locale/locale-archive
              # This tells programs to use the locale from our archive
              export LC_ALL='en_US.UTF-8'
            fi
          ''
        else
          "";

      activationSnippet = pipe activation [
        (activation: getAttrs activation homeConfig.config.home.activation)
        attrValues
        (catAttrs "data")
        (concatStringsSep "\n")
      ];
    in
    ''
      ${localeSnippet}
      ${activationSnippet}
    '';

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
          "$set_xdg_env" = true;
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
  INIT_SNIPPET=${escapeShellArg initSnippet}
  source ${bootstrap}/bin/bootstrap
'')
// {
  meta.mainProgram = programName;
}
