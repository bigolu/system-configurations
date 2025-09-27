{
  pkgs,
  lib,
  hasGui,
  inputs,
  config,
  utils,
  pins,
  ...
}:
let
  inherit (lib)
    optionalAttrs
    optionals
    getExe
    ;
  inherit (pkgs) writeText;
  inherit (pkgs.stdenv) isDarwin isLinux;
  inherit (utils) projectRoot;

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
  imports = [
    ./utility/repository.nix
    ./utility/system.nix
    "${inputs.nix-flatpak}/modules/home-manager.nix"
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
      optionals config.repository.fileSettings.editableInstall [
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

    file = optionalAttrs isDarwin {
      ".hammerspoon/Spoons/EmmyLua.spoon" = {
        # TODO: I should do a sparse checkout to get the single Hammerspoon Spoon I
        # need. issue: https://github.com/NixOS/nix/issues/5811
        source = "${pins.spoons}/Source/EmmyLua.spoon";
        # I'm not symlinking the whole directory because EmmyLua is going to generate
        # lua-language-server annotations in there.
        recursive = true;
      };
    };
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

  # When switching generations, stop obsolete services and start ones that are wanted
  # by active units.
  systemd = optionalAttrs isLinux {
    user.startServices = "sd-switch";
  };

  repository = {
    fileSettings = {
      editableInstall = true;
      relativePathRoot = "${toString projectRoot}/dotfiles";
    };

    xdg.executable = {
      "general" = {
        source = "general/bin";
        recursive = true;
      };
    };
  };
}
