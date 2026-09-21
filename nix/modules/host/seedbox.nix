{
  _class,
  myUtils,
  primaryUser,
  lib,
  pkgs,
  ...
}:
{
  "" =
    let
      inherit (pkgs)
        resholve
        replaceVars
        runCommand
        makeWrapper
        ;
      inherit (lib) getExe makeBinPath;
      inherit (myUtils) programConfigRoot;

      seedboxRoot = programConfigRoot + /seedbox;

      autobrr-filter =
        let
          name = "autobrr-filter";
        in
        runCommand name
          {
            nativeBuildInputs = [ makeWrapper ];
            buildInputs = [ pkgs.nushell ];
            meta.mainProgram = name;
          }
          ''
            mkdir --parents $out/bin
            cp ${seedboxRoot + /autobrr-filter.nu} $out/bin/${name}
            chmod +x $out/bin/${name}
            patchShebangs $out/bin/${name}
            wrapProgram $out/bin/${name} \
              --prefix PATH : ${makeBinPath [ pkgs.intermodal ]}
          '';

      seedbox = resholve.mkDerivation rec {
        pname = "seedbox";
        version = "0.1.0";
        src = replaceVars (seedboxRoot + /main.bash) {
          qbittorrent_config = "${seedboxRoot + /qBittorrent.conf}";
          watched_folders = "${seedboxRoot + /watched_folders.json}";
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
      home-manager.users.${primaryUser}.systemd.user.services.seedbox = {
        Service.ExecStart = getExe seedbox;
        Install.WantedBy = [ "default.target" ];
        Unit.X-Restart-Triggers = [ "${seedboxRoot}" ];
      };
    };
}
.${toString _class}
