{ nixpkgs, ... }:
nixpkgs.callPackage (
  {
    stdenv,
    lib,
    bash,
    glibcLocales,
    resholve,
    coreutils,
    writeScriptBin,
  }:
  {
    homeConfig,
    shell,
    activation ? [ ],
  }:
  let
    inherit (builtins) attrValues catAttrs;
    inherit (stdenv) isLinux;
    inherit (lib)
      escapeShellArg
      getAttrs
      concatStringsSep
      pipe
      ;

    bashPath = "${bash}/bin/bash";
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
            locales = glibcLocales.override {
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

    bootstrap = resholve.mkDerivation {
      pname = "bootstrap-home-shell";
      version = "0.0.1";
      src = ./bootstrap.bash;
      dontConfigure = true;
      dontBuild = true;
      dontUnpack = true;
      installPhase = ''
        install -D $src $out/bin/bootstrap
      '';
      solutions = {
        default = {
          scripts = [ "bin/bootstrap" ];
          interpreter = bashPath;
          inputs = [ coreutils ];
          execer = [
            "cannot:${coreutils}/bin/mktemp"
            "cannot:${coreutils}/bin/mkdir"
            "cannot:${coreutils}/bin/ln"
            "cannot:${coreutils}/bin/chmod"
            "cannot:${coreutils}/bin/cp"
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
  (writeScriptBin programName ''
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
) { }
