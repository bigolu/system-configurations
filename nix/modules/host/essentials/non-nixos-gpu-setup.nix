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
      inherit (pkgs) linkFarm runCommand replaceVars;
      inherit (lib)
        getExe
        pipe
        escapeShellArg
        makeBinPath
        ;
      inherit (myUtils) programConfigRoot;
      inherit (builtins) toJSON;

      nonNixosGpuRoot = programConfigRoot + /nix/non-nixos-gpu-setup;

      nonNixosGpuService = pipe (nonNixosGpuRoot + /setup.nu) [
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
        (setupScript: replaceVars (nonNixosGpuRoot + /non-nixos-gpu-x.service) { inherit setupScript; })
      ];
    in
    {
      systemd = {
        packages = [
          (linkFarm "non-nixos-gpu-setup-units" {
            "lib/systemd/system/non-nixos-gpu-x.service" = nonNixosGpuService;
            "lib/systemd/system/non-nixos-gpu-x.path" = nonNixosGpuRoot + /non-nixos-gpu-x.path;
          })
        ];
        # SYNC: non-nixos-gpu-path-wanted-by
        paths.non-nixos-gpu-x.wantedBy = [ "multi-user.target" ];
        # SYNC: non-nixos-gpu-service-wanted-by
        services.non-nixos-gpu-x.wantedBy = [ "multi-user.target" ];
      };
    };
}
.${toString _class}
