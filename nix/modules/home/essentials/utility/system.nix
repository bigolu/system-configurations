# Stopgap for missing options in system-manager.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    hm
    optionalAttrs
    mapAttrs
    ;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  options.system.activation = mkOption {
    type = hm.types.dagOf types.str;
    default = { };
  };

  config = {
    home.activation = mapAttrs (
      _: value:
      value
      // {
        data = ''
          # Add /usr/bin so scripts can access system programs like sudo/apt
          # Apparently macOS hasn't merged /bin and /usr/bin so add /bin too.
          OLD_PATH="$PATH"
          PATH="$PATH:/usr/bin:/bin"
          ${value.data}
          PATH="$OLD_PATH"
        '';
      }
    ) config.system.activation;

    system.activation = optionalAttrs isLinux {
      # Needs to happen after udev rules are installed and I think
      # system-manager links files in /etc before calling home-manager so
      # `entryAnywhere` should be fine.
      udev = hm.dag.entryAnywhere ''
        sudo udevadm control --reload-rules
        sudo udevadm trigger
      '';
    };
  };
}
