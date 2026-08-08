{
  _class,
  inputs,
  primaryUser,
  pkgs,
  ...
}:
let
  darwinAndSystem = {
    home-manager.users.${primaryUser} = {
      imports = [ (import "${inputs.nix-index-database}/home-manager-module.nix") ];

      # Don't make a `command_not_found` handler
      programs.nix-index.enableFishIntegration = false;

      fileWrapper.xdg.configFile = {
        "nix/repl-overlay.nix".source = "nix/repl-overlay.nix";
        "nix/nix.conf".source = "nix/nix.conf";
      };

      nix.registry.nixpkgs.flake = inputs.nixpkgs;

      home.packages = with pkgs; [
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
  };
in
{
  "" = {
    imports = [ darwinAndSystem ];

    home-manager.users.${primaryUser} = { lib, ... }: {
      # qemu can only access /dev/kvm from the build sandbox if it's world
      # readable/writable. qemu is run in the sandbox for NixOS tests, for
      # example. Without KVM acceleration, qemu would be much slower.
      home.activation.allowKvmAccess = lib.hm.dag.entryAnywhere ''
        /usr/bin/sudo /usr/bin/chmod o+rw /dev/kvm
      '';
    };
  };

  darwin = {
    imports = [ darwinAndSystem ];

    # I don't want nix-darwin to manage the system nix config or the nix installation.
    nix.enable = false;
  };
}
.${toString _class}
