# This module has the configuration that I always want applied.

{
  pkgs,
  config,
  lib,
  isGui,
  repositoryDirectory,
  inputs,
  utils,
  ...
}:
let
  inherit (lib)
    optionalAttrs
    optionals
    hm
    escapeShellArg
    fileset
    ;
  inherit (pkgs) writeText;
  inherit (pkgs.stdenv) isDarwin isLinux;
  inherit (utils) projectRoot;

  isLinuxGui = isGui && isLinux;

  sudoersFile =
    let
      group = if isLinux then "sudo" else "admin";
    in
    writeText "10-bigolu" ''
      %${group} ALL=(ALL:ALL) NOPASSWD: ${pkgs.runAsAdmin}/bin/run-as-admin
      Defaults  env_keep += "TERMINFO"
      Defaults  env_keep += "PATH"
      Defaults  timestamp_timeout=30
    '';
in
{
  imports = [
    ../default-shells.nix
    ../fish.nix
    ../nix.nix
    ../neovim.nix
    ../utility/repository.nix
    ../utility/system.nix
    ../home-manager.nix
    ../fonts.nix
    ../keyboard-shortcuts.nix
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  system.file."/etc/sudoers.d/10-bigolu".source = sudoersFile;

  home = {
    packages =
      with pkgs;
      [
        # For my shebang scripts
        bashInteractive
      ]
      ++ optionals isLinuxGui [
        # TODO: Only doing this because Pop!_OS doesn't come with it by default, but
        # I think it should
        wl-clipboard
      ];

    activation = optionalAttrs isLinuxGui {
      # TODO: Flatpak didn't read the overrides when the files were symlinks to the
      # Nix store so I'm making copies instead.
      flatpakOverrides = hm.dag.entryAfter [ "writeBoundary" ] ''
        target=${escapeShellArg "${config.xdg.dataHome}/flatpak/overrides/"}
        mkdir -p "$target"
        cp --no-preserve=mode --dereference ${
          escapeShellArg (
            fileset.toSource {
              root = projectRoot + /dotfiles/flatpak/overrides;
              fileset = projectRoot + /dotfiles/flatpak/overrides;
            }
          )
        }/* "$target"
      '';
    };

    file = optionalAttrs isDarwin {
      ".hammerspoon/Spoons/EmmyLua.spoon" = {
        source = "${inputs.spoons}/Source/EmmyLua.spoon";
        # I'm not symlinking the whole directory because EmmyLua is going to generate
        # lua-language-server annotations in there.
        recursive = true;
      };
    };
  };

  services.flatpak.enable = isLinuxGui;

  # When switching generations, stop obsolete services and start ones that are wanted
  # by active units.
  systemd = optionalAttrs isLinux {
    user.startServices = "sd-switch";
  };

  repository = {
    fileSettings = {
      editableInstall = true;
      relativePathRoot = "${repositoryDirectory}/dotfiles";
      flake.root = {
        path = repositoryDirectory;
        storePath = projectRoot;
      };
    };

    xdg.executable =
      {
        "general" = {
          source = "general/bin";
          recursive = true;
        };
      }
      // optionalAttrs isDarwin {
        "general macOS" = {
          source = "general/bin-macos";
          recursive = true;
        };
      };
  };
}
