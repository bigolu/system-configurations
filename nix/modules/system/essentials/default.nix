{
  system,
  hostName,
  hasGui,
}:
{
  pkgs,
  lib,
  myUtils,
  ...
}:
let
  inherit (pkgs) writeText;
  inherit (lib) getExe;
  inherit (myUtils) projectRoot;

  # On macOS, "admin" should be used instead of sudo.
  sudoersFile = writeText "10-bigolu" ''
    %sudo ALL=(ALL:ALL) NOPASSWD: ${getExe pkgs.run-as-admin}
    Defaults  env_keep += "TERMINFO"
    Defaults  env_keep += "PATH"
    Defaults  timestamp_timeout=30
  '';
in
{
  imports = [
    ./non-nixos-gpu-setup.nix
    ./home-manager.nix
    ./keyd.nix
  ];

  _module.args = {
    pkgs = lib.mkForce (import ../../../packages.nix { inherit system; });
    myUtils = import ../../../utils.nix;
    pins = import ../../../pins pkgs;
    inherit hasGui;
    inherit hostName;
  };

  system-manager.allowAnyDistro = true;
  nixpkgs.hostPlatform = system;

  environment = {
    pathsToLink = [ "/share" ];
    extraInit = ''
      user_share_dir="/etc/profiles/per-user/$USER/share"
      if [ -d "$user_share_dir" ]; then
        export XDG_DATA_DIRS="$user_share_dir''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      fi
    '';

    etc = {
      "udev/rules.d/99-keychron-launcher.rules".source =
        projectRoot + /program-configs/keychron-launcher/99-keychron-launcher.rules;
      "sudoers.d/10-bigolu".source = sudoersFile;
    };
  };

  home-manager.users.biggs =
    { lib, ... }:
    let
      inherit (lib) hm;
    in
    {
      home.activation = {
        # Needs to happen after udev rules are installed and I think
        # system-manager links files in /etc before calling home-manager so
        # `entryAnywhere` should be fine.
        #
        # TODO: I'd rather set `restartTriggers` on the `systemd-udevd` service,
        # but my distro makes that service and if I set `restartTriggers`,
        # system-manager replaces the entire service definition.
        udev = hm.dag.entryAnywhere ''
          /usr/bin/sudo udevadm control --reload-rules
          /usr/bin/sudo udevadm trigger
        '';
      };
    };
}
