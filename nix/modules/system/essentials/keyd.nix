{ pkgs, myUtils, ... }:
let
  inherit (myUtils) projectRoot;
in
{
  environment.etc."keyd/default.conf".source = projectRoot + /program-configs/keyd/default.conf;

  systemd = {
    packages = [ pkgs.keyd ];
    services.keyd.wantedBy = [ "multi-user.target" ];
  };
}
