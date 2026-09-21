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
      inherit (pkgs) runCommand makeWrapper;
      inherit (lib)
        getExe
        makeBinPath
        pipe
        escapeShellArg
        ;
      inherit (myUtils) programConfigRoot;
      inherit (builtins) toJSON;

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

      seedbox =
        let
          name = "seedbox";
        in
        runCommand name
          {
            nativeBuildInputs = [ makeWrapper ];
            buildInputs = [ pkgs.nushell ];
            meta.mainProgram = name;
          }
          ''
            mkdir --parents $out/bin
            cp ${seedboxRoot + /main.nu} $out/bin/${name}
            chmod +x $out/bin/${name}
            patchShebangs $out/bin/${name}
            wrapProgram $out/bin/${name} \
              --prefix PATH : ${
                makeBinPath (
                  with pkgs;
                  [
                    qbittorrent-nox
                    autobrr
                    autobrr-filter
                  ]
                )
              } \
              --set CONTEXT ${
                pipe
                  {
                    qbittorrentConfig = "${seedboxRoot + /qBittorrent.conf}";
                    watchedFolders = "${seedboxRoot + /watched_folders.json}";
                    autobrrConfig = "${seedboxRoot + /config.toml}";
                  }
                  [
                    toJSON
                    escapeShellArg
                  ]
              }
          '';
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
