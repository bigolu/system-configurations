{
  pkgs,
  specialArgs,
  lib,
  ...
}:
let
  inherit (specialArgs) flakeInputs;
  inherit (pkgs.stdenv) isLinux;
  inherit (lib.lists) optionals;
  # TODO: Won't be needed if the daemon auto-reloads:
  # https://github.com/NixOS/nix/issues/8939
  nix-daemon-reload = pkgs.writeShellApplication {
    name = "nix-daemon-reload";
    text = ''
      if uname | grep -q Linux; then
        systemctl restart nix-daemon.service
      else
        sudo launchctl stop org.nixos.nix-daemon && sudo launchctl start org.nixos.nix-daemon
      fi
    '';
  };
in
{
  imports = [
    flakeInputs.nix-index-database.hmModules.nix-index
  ];

  # Don't make a command_not_found handler
  programs.nix-index.enableFishIntegration = false;

  home.packages =
    with pkgs;
    [
      nix-tree
      nix-melt
      comma
      nix-daemon-reload
      nix-output-monitor
      nix-diff
      nix-search-cli
    ]
    ++ optionals isLinux [
      # for breakpointHook:
      # https://nixos.org/manual/nixpkgs/stable/#breakpointhook
      cntr
    ];

  repository = {
    symlink.xdg = {
      executable."nix" = {
        source = "nix/bin";
        recursive = true;
      };

      configFile = {
        "nix/repl-startup.nix".source = "nix/repl-startup.nix";
        "fish/conf.d/zz-nix.fish".source = "nix/zz-nix.fish";
      };
    };
  };

  nix = {
    registry = {
      # Use the nixpkgs in this flake in the system flake registry. By default, it
      # pulls the latest version of nixpkgs-unstable.
      nixpkgs.flake = flakeInputs.nixpkgs;

      # In case something is broken on unstable
      nixpkgs-stable.flake = flakeInputs.nixpkgs-stable;
    };

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Always show the entire stack of an error.
      show-trace = true;

      # Don't warn me that the git repository is dirty
      warn-dirty = false;

      # Not sure if anything in nix still reads this, but I'll set it just in case.
      nix-path = [ "nixpkgs=flake:nixpkgs" ];

      # Disable the global flake registry until they stop fetching it
      # unnecessarily: https://github.com/NixOS/nix/issues/9087
      flake-registry = null;

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
    };
  };
}
