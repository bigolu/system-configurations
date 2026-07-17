{ pkgs, inputs, ... }: {
  imports = [ (import "${inputs.nix-index-database}/home-manager-module.nix") ];

  # Don't make a `command_not_found` handler
  programs.nix-index.enableFishIntegration = false;

  fileWrapper.xdg.configFile = {
    "nix/repl-overlay.nix".source = "nix/repl-overlay.nix";
    "nix/nix.conf".source = "nix/nix.conf";
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;

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
  };
}
