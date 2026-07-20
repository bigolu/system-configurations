{ pkgs, ... }:
let
  inherit (pkgs) writeText runCommand;
in
{
  environment = {
    systemPackages = [ pkgs.s ];

    etc."sudoers.d/10-bigolu".source = runCommand "sudoers" {
      # On macOS, "admin" should be used instead of sudo.
      src = writeText "10-bigolu" ''
        %sudo ALL=(ALL:ALL) NOPASSWD: ^.*/s$
        Defaults timestamp_timeout=30
        Defaults !secure_path
        Defaults !env_reset
        # On Pop!_OS, TERMINFO is removed by default
        Defaults !env_delete
      '';
    } "${pkgs.sudo}/sbin/visudo -cf $src && cp $src $out";
  };
}
