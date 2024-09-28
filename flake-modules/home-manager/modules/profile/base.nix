# This module has the configuration that I always want applied.
{
  pkgs,
  config,
  lib,
  specialArgs,
  ...
}:
{
  imports = [
    ../default-shells.nix
    ../fish.nix
    ../nix.nix
    ../neovim.nix
    ../general.nix
    ../utility
    ../home-manager.nix
    ../fonts.nix
    ../keyboard-shortcuts.nix
    specialArgs.flakeInputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  home.packages =
    with pkgs;
    [
      # for my shebang scripts
      bashInteractive
      myPython
      fish
    ]
    ++ lib.lists.optionals specialArgs.isGui [
      # TODO: Only doing this because Pop!_OS doesn't come with it by default, but
      # I think it should
      wl-clipboard
    ];

  services.flatpak.enable = pkgs.stdenv.isLinux && specialArgs.isGui;

  # TODO: Flatpak didn't read the overrides when the files were symlinks to the
  # Nix store so I'm making copies instead.
  home.activation.flatpakOverrides = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    if (pkgs.stdenv.isLinux && specialArgs.isGui) then
      ''
        target=${lib.escapeShellArg "${config.xdg.dataHome}/flatpak/overrides/"}
        mkdir -p "$target"
        cp --no-preserve=mode --dereference ${
          lib.escapeShellArg (
            lib.fileset.toSource {
              root = specialArgs.root + "/dotfiles/flatpak/overrides";
              fileset = specialArgs.root + "/dotfiles/flatpak/overrides";
            }
          )
        }* "$target"
      ''
    else
      ""
  );
}
