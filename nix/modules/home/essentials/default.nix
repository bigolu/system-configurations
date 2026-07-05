{
  pkgs,
  lib,
  hasGui,
  inputs,
  config,
  utils,
  repositoryDirectory,
  ...
}:
let
  inherit (builtins) storeDir;
  inherit (lib)
    optionalAttrs
    optionals
    getExe
    inPureEvalMode
    isPath
    cleanSourceWith
    hasPrefix
    ;

  inherit (utils) projectRoot callIf;
  inherit (pkgs) writeText;
  inherit (pkgs.stdenv.hostPlatform) isLinux;

  isLinuxAndHasGui = isLinux && hasGui;

  sudoersFile =
    let
      group = if isLinux then "sudo" else "admin";
    in
    writeText "10-bigolu" ''
      %${group} ALL=(ALL:ALL) NOPASSWD: ${getExe pkgs.run-as-admin}
      Defaults  env_keep += "TERMINFO"
      Defaults  env_keep += "PATH"
      Defaults  timestamp_timeout=30
    '';
in
{
  _module.args = {
    repositoryDirectory = "${config.home.homeDirectory}/code/system-configurations";
    pins = import ../../../pins pkgs;
    utils = import ../../../utils.nix;
  };

  imports = [
    inputs.home-manager-file-wrapper.homeModules.file-wrapper
    "${inputs.nix-flatpak}/modules/home-manager.nix"
    ./utility/system.nix
    ./home-manager.nix
    ./nix.nix
    ./terminal
    ./keyboard-shortcuts.nix
    ./fonts.nix
    ./default-shells.nix
  ];

  system.file."/etc/sudoers.d/10-bigolu".source = sudoersFile;

  home = {
    packages =
      with pkgs;
      optionals config.fileWrapper.settings.editableInstall [
        # For my shebang scripts
        bash
      ]
      ++ optionals isLinuxAndHasGui [
        # TODO: Only doing this because Pop!_OS doesn't come with it by default, but
        # I think it should
        #
        # TODO: It causes issues with the COSMIC compositor[1].
        #
        # [1]: https://github.com/pop-os/cosmic-comp/issues/700
        wl-clipboard
      ];
  };

  services.flatpak = {
    enable = isLinuxAndHasGui;
    overrides.global = {
      Context.filesystems = [
        "xdg-config/gtk-4.0:ro"
        # Since some of my configs are symlinks to the nix store, flatpaks need
        # access
        "/nix"
      ];
    };
  };

  fileWrapper = {
    settings = {
      editableInstall = true;

      relativePathRoot = {
        access = (if inPureEvalMode then inputs.self.outPath else projectRoot) + "/program-configs";
      }
      // optionalAttrs inPureEvalMode { symlink = "${repositoryDirectory}/program-configs"; };

      # Flakes have built-in gitignore support
      directoryFilter = callIf (!inPureEvalMode) (
        let
          # PERF: As per the documentation[1], we memoize this.
          #
          # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
          filter = inputs.gitignore.lib.gitignoreFilterWith { basePath = projectRoot; };
        in
        stringOrPath:
        cleanSourceWith {
          inherit filter;
          # Clean source won't accept a string
          src =
            if (isPath stringOrPath || hasPrefix storeDir stringOrPath) then
              stringOrPath
            else
              /. + stringOrPath;
        }
      );
    };

    xdg.executable = {
      "general" = {
        source = "general/bin";
        recursive = true;
      };
    };
  };
}
