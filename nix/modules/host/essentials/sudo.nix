{ _class, pkgs, ... }:
{
  "" =
    let
      inherit (pkgs) writeText runCommand;
    in
    {
      environment = {
        systemPackages = [ pkgs.s ];

        etc."sudoers.d/10-bigolu".source = runCommand "sudoers" {
          src = writeText "10-bigolu" ''
            %sudo ALL=(ALL:ALL) NOPASSWD: ^.*/s$
            Defaults timestamp_timeout=30
            Defaults !secure_path
            Defaults !env_reset
            Defaults !env_delete
          '';
        } "${pkgs.sudo}/sbin/visudo -cf $src && cp $src $out";
      };
    };
}
.${toString _class}
