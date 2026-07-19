{
  utils,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs) resholve replaceVars;
  inherit (lib) getExe;
  inherit (utils) programConfigRoot;

  seedboxRoot = programConfigRoot + /seedbox;

  autobrr-filter = resholve.mkDerivation rec {
    pname = "autobrr-filter";
    version = "0.1.0";
    src = seedboxRoot + /autobrr-filter.bash;
    meta.mainProgram = pname;
    dontUnpack = true;
    installPhase = ''
      install -D $src $out/bin/${pname}
    '';
    solutions.default = {
      scripts = [ "bin/${pname}" ];
      interpreter = "${pkgs.bash}/bin/bash";
      inputs = with pkgs; [
        coreutils
        intermodal
        jq
      ];
      execer = [ "cannot:${getExe pkgs.intermodal}" ];
    };
  };

  seedbox = resholve.mkDerivation rec {
    pname = "seedbox";
    version = "0.1.0";
    src = replaceVars (seedboxRoot + /main.bash) {
      qbittorrent_config = "${seedboxRoot + /qBittorrent.conf}";
      autobrr_config = "${seedboxRoot + /config.toml}";
      autobrr_filter_bin = "${autobrr-filter}/bin";
    };
    meta.mainProgram = pname;
    dontUnpack = true;
    installPhase = ''
      install -D $src $out/bin/${pname}
    '';
    solutions.default = {
      scripts = [ "bin/${pname}" ];
      interpreter = "${pkgs.bash}/bin/bash";
      inputs = with pkgs; [
        coreutils
        qbittorrent-nox
        autobrr
        sd
      ];
      execer = [
        "cannot:${getExe pkgs.qbittorrent-nox}"
        "cannot:${getExe pkgs.sd}"
        "cannot:${getExe pkgs.autobrr}"
      ];
    };
  };
in
{
  systemd.user.services.seedbox = {
    Service.ExecStart = getExe seedbox;
    Install.WantedBy = [ "default.target" ];
    Unit.X-Restart-Triggers = [ "${seedboxRoot}" ];
  };
}
