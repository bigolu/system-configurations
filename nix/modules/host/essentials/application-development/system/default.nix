{ pkgs, primaryUser, ... }: {
  imports = [ ./podman.nix ];

  home-manager.users.${primaryUser}.home.packages = with pkgs; [
    ghostty
    vscode
  ];
}
