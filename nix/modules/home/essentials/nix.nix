{
  pkgs,
  inputs,
  lib,
  repositoryDirectory,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
  inherit (lib)
    optionalAttrs
    optionalString
    ;
in
{
  imports = [
    (import "${inputs.nix-index-database}/home-manager-module.nix")
  ];

  # Don't make a command_not_found handler
  programs.nix-index.enableFishIntegration = false;

  fileWrapper.xdg.configFile = {
    "nix/repl-overlay.nix".source = "nix/repl-overlay.nix";
    "nix/nix.conf".source = "nix/nix.conf";
  };

  system = {
    file = {
      "/usr${optionalString isDarwin "/local"}/share/fish/vendor_conf.d/zz-nix-fix.fish".source =
        "${repositoryDirectory}/dotfiles/nix/zz-nix-fix.fish";
    };
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-old";
      dates = "monthly";
    };

    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  home = {
    packages = with pkgs; [
      nix-tree
      nix-melt
      lixPackageSet.comma
      nix-diff
      nix-search-cli
      nix-sweep
      nixpkgs-track
      dix
    ];

    activation = {
      removeOldUserProfileGenerations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        nix-env --delete-generations old
      '';
    };
  };
}
