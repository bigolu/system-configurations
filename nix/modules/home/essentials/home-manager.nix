{
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
let
  inherit (lib) mkMerge mkIf;
in
mkMerge [
  {
    # The `man` in nixpkgs is only intended to be used for NixOS, it doesn't work
    # properly on other OS's so I'm disabling it.
    #
    # home-manager issue: https://github.com/nix-community/home-manager/issues/432
    programs.man.enable = false;

    xdg.stateFile."bigolu/system-config-name".text =
      if config.submoduleSupport.enable then hostName else "${config.home.username}@${hostName}";

    home = {
      # Since I'm not using the nixpkgs man, I have any packages I install their man
      # outputs so my system's `man` can find them.
      extraOutputsToInstall = [ "man" ];

      # This value determines the Home Manager release that your
      # configuration is compatible with. This helps avoid breakage
      # when a new Home Manager release introduces backwards
      # incompatible changes.
      #
      # You can update Home Manager without changing this value. See
      # the Home Manager release notes for a list of state version
      # changes in each release.
      stateVersion = "23.11";
    };
  }

  # These are all things that don't need to be done when home manager is being run as
  # a submodule inside of another system manager, like nix-darwin. They don't need to
  # be done because the outer system manager will do them.
  (mkIf (!config.submoduleSupport.enable) {
    nix.package = pkgs.nix;
    news.display = "silent";
    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
  })
]
