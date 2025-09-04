{ nixpkgs, ... }:
nixpkgs.callPackage (
  {
    stdenv,
    lib,
    bash,
    resholve,
    coreutils,
    writeScriptBin,

    glibcLocales ? null,
    withLocales ? stdenv.isLinux,
    locales ? null,
  }:

  assert withLocales -> stdenv.isLinux && glibcLocales != null;

  {
    homeConfig,
    shell,
    activation ? [ ],
  }:
  let
    inherit (lib)
      escapeShellArg
      concatMapStringsSep
      optionalString
      getExe
      ;

    bashPath = "${bash}/bin/bash";
    inherit (homeConfig) activationPackage;

    initScript =
      let
        # Nix recommends setting the LOCALE_ARCHIVE environment variable for non-NixOS
        # Linux distributions[1].
        #
        # [1]: https://nixos.wiki/wiki/Locales
        localeScript =
          let
            localePackage =
              if locales == null then
                glibcLocales
              else
                glibcLocales.override {
                  allLocales = false;
                  inherit locales;
                };
          in
          optionalString withLocales ''
            if [[ -z ''${LOCALE_ARCHIVE:-} ]]; then
              export LOCALE_ARCHIVE=${localePackage}/lib/locale/locale-archive
              # This tells programs to use the locale from our archive
              export LC_ALL='en_US.UTF-8'
            fi
          '';

        activationScript = concatMapStringsSep "\n" (
          name: homeConfig.config.home.activation.${name}.data
        ) activation;
      in
      ''
        ${localeScript}
        ${activationScript}
      '';

    setup =
      let
        name = "setup";
      in
      resholve.mkDerivation {
        pname = "home-shell-${name}";
        version = "0.0.1";
        src = ./setup.bash;
        dontConfigure = true;
        dontBuild = true;
        dontUnpack = true;
        installPhase = ''
          install -D $src $out/bin/${name}
        '';
        meta.mainProgram = name;
        solutions = {
          default = {
            scripts = [ "bin/${name}" ];
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

    programName = "${homeConfig.config.home.username}-shell";
  in
  (writeScriptBin programName ''
    #!${bashPath}
    BASH_PATH=${bashPath}
    ACTIVATION_PACKAGE=${activationPackage}
    USER_SHELL=${escapeShellArg shell}
    INIT_SCRIPT=${escapeShellArg initScript}
    source ${getExe setup}
  '')
  // {
    meta.mainProgram = programName;
  }
) { }
