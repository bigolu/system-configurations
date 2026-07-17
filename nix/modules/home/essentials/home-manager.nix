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
    xdg.stateFile."bigolu/system-config-name".text =
      if config.submoduleSupport.enable then hostName else "${config.home.username}@${hostName}";

    # The `man` in nixpkgs is only intended to be used for NixOS[1] so I'm
    # disabling it.
    #
    # [1]: https://github.com/nix-community/home-manager/issues/432
    programs.man.enable = false;

    home = {
      stateVersion = "23.11";
      # Since I'm not using the `man` from nixpkgs, I install my packages' `man`
      # outputs so my system's `man` can find them.
      extraOutputsToInstall = [ "man" ];
    };
  }

  # These are things that don't need to be done when home manager is being run as
  # a submodule inside of another system manager, like nix-darwin. They don't need to
  # be done because the outer system manager will do them.
  (mkIf (!config.submoduleSupport.enable) {
    news.display = "silent";
    # TODO: I'd like to use lix, but it didn't work.
    nix.package = pkgs.nix;
    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
  })
]
