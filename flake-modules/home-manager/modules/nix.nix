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
      nix-derivation
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
        "nix/nix.conf".source = "nix/nix.conf";
        "nix/repl-startup.nix".source = "nix/repl-startup.nix";
        "fish/conf.d/zz-nix.fish".source = "nix/zz-nix.fish";
      };
    };
  };

  # Use the nixpkgs in this flake in the system flake registry. By default, it pulls the
  # latest version of nixpkgs-unstable.
  nix.registry = {
    nixpkgs.flake = flakeInputs.nixpkgs;
  };
}
