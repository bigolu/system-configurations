{
  _class,
  pkgs,
  lib,
  myUtils,
  inputs,
  ...
}:
{
  "" =
    let
      inherit (pkgs) runCommand;
      inherit (lib)
        getExe
        pipe
        escapeShellArg
        makeBinPath
        ;
      inherit (myUtils) programConfigRoot;
      inherit (builtins) toJSON;

      nonNixosGpuRoot = programConfigRoot + /nix/non-nixos-gpu-setup;

      exe = pipe (nonNixosGpuRoot + /setup.nu) [
        (
          setupScript:
          let
            name = "setup";
          in
          runCommand name
            {
              nativeBuildInputs = [ pkgs.makeWrapper ];
              buildInputs = [ pkgs.nushell ];
              meta.mainProgram = name;
            }
            ''
              mkdir --parents $out/bin
              cp ${setupScript} $out/bin/${name}
              chmod +x $out/bin/${name}
              patchShebangs $out/bin/${name}
              wrapProgram $out/bin/${name} \
                --prefix PATH : ${makeBinPath [ pkgs.nushell ]} \
                --set CONTEXT ${
                  pipe
                    {
                      setupNix = "${nonNixosGpuRoot + /setup.nix}";
                      homeManager = inputs.home-manager;
                    }
                    [
                      toJSON
                      escapeShellArg
                    ]
                }
            ''
        )
        getExe
      ];
    in
    {
      systemd.tmpfiles.settings."10-non-nixos-gpu"."/etc/apt/apt.conf.d/99non-nixos-gpu" = {
        "f+" = {
          mode = "0644";
          user = "root";
          group = "root";
          argument = ''DPkg::Post-Invoke {"${exe}";};'';
        };
      };
    };
}
.${toString _class}
