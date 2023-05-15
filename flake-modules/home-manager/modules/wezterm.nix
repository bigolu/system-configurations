{ config, lib, specialArgs, ... }:
  let
    inherit (specialArgs) isGui;
  in lib.mkIf isGui {
    # TODO: Wezterm doesn't read my config when I symlink it so
    # For now I'll symlink directly into my dotfiles repo. Might have to do with the fact
    # that the symlink links into the Nix store?
    home.activation.weztermSetup = lib.hm.dag.entryAfter
      ["linkGeneration"]
      ''
        wezterm_config='${config.home.homeDirectory}/.wezterm.lua'
        if [ -L $wezterm_config ]; then
          rm "$wezterm_config"
        fi
        ln --symbolic ${config.repository.symlink.baseDirectory}/wezterm/wezterm.lua $wezterm_config
      '';
  }