# This module has the configuration that I always want applied.

{
  pkgs,
  config,
  lib,
  specialArgs,
  ...
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (pkgs.stdenv) isDarwin isLinux;
  isLinuxGui = specialArgs.isGui && isLinux;
  inherit (specialArgs) repositoryDirectory root;
in
{
  imports = [
    ../default-shells.nix
    ../fish.nix
    ../nix.nix
    ../neovim.nix
    ../utility
    ../home-manager.nix
    ../fonts.nix
    ../keyboard-shortcuts.nix
    specialArgs.flakeInputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  home = {
    packages =
      with pkgs;
      [
        # For my shebang scripts
        bashInteractive
      ]
      ++ lib.lists.optionals isLinuxGui [
        # TODO: Only doing this because Pop!_OS doesn't come with it by default, but
        # I think it should
        wl-clipboard
      ];

    activation =
      {
        addRunAsAdminToSudoers =
          let
            sudoersFile =
              let
                group = if isLinux then "sudo" else "admin";
              in
              pkgs.writeText "10-run-as-admin" ''
                %${group} ALL=(ALL:ALL) NOPASSWD: ${pkgs.runAsAdmin}/bin/run-as-admin
              '';
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            # Add /usr/bin so scripts can access system programs like sudo/apt
            PATH="$PATH:/usr/bin"

            sudo ln --symbolic --force --no-dereference \
              ${sudoersFile} /etc/sudoers.d/10-run-as-admin
          '';
      }
      // optionalAttrs isLinuxGui {
        # TODO: Flatpak didn't read the overrides when the files were symlinks to the
        # Nix store so I'm making copies instead.
        flatpakOverrides = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          target=${lib.escapeShellArg "${config.xdg.dataHome}/flatpak/overrides/"}
          mkdir -p "$target"
          cp --no-preserve=mode --dereference ${
            lib.escapeShellArg (
              lib.fileset.toSource {
                root = specialArgs.root + "/dotfiles/flatpak/overrides";
                fileset = specialArgs.root + "/dotfiles/flatpak/overrides";
              }
            )
          }/* "$target"
        '';
      };

    file = optionalAttrs isDarwin {
      ".hammerspoon/Spoons/EmmyLua.spoon" = {
        source = "${specialArgs.flakeInputs.spoons}/Source/EmmyLua.spoon";
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
    directory = repositoryDirectory;
    directoryPath = root;

    symlink = {
      baseDirectory = "${repositoryDirectory}/dotfiles";

      xdg = {
        executable =
          {
            "general" = {
              source = "general/bin";
              recursive = true;
            };
          }
          // lib.optionalAttrs isDarwin {
            "general macOS" = {
              source = "general/bin-macos";
              recursive = true;
            };
          };
      };
    };
  };
}
