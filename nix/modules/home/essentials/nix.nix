{
  pkgs,
  inputs,
  lib,
  repositoryDirectory,
  ...
}:
let
  inherit (pkgs) stdenv;
  inherit (stdenv) isLinux isDarwin;
  inherit (lib)
    optionals
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
    }
    // optionalAttrs isLinux {
      "/etc/profile.d/bigolu-nix-locale-variable.sh".source =
        "${repositoryDirectory}/dotfiles/nix/bigolu-nix-locale-variable.sh";
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
    packages =
      with pkgs;
      [
        nix-tree
        nix-melt
        lixPackageSet.comma
        nix-diff
        nix-search-cli
        nix-sweep
        nixpkgs-track
        dix
      ]
      ++ optionals isLinux [
        # for breakpointHook:
        # https://nixos.org/manual/nixpkgs/stable/#breakpointhook
        cntr
        nix-gl-host
      ];

    activation = {
      removeOldUserProfileGenerations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        nix-env --delete-generations old
      '';
    };
  };
}
