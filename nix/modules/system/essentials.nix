{
  system,
  hostName,
  hasGui,
}:
{
  pkgs,
  lib,
  myUtils,
  inputs,
  ...
}:
let
  inherit (pkgs)
    linkFarm
    resholve
    replaceVars
    writeText
    ;
  inherit (lib) getExe optionals optionalAttrs;
  inherit (myUtils) projectRoot;

  nonNixosGpuRoot = projectRoot + /program-configs/nix/non-nixos-gpu-setup;
  nonNixosGpuService =
    let
      pname = "setup";
      setupBash = resholve.mkDerivation {
        inherit pname;
        version = "0.1.0";
        src = replaceVars (nonNixosGpuRoot + /setup.bash) {
          setupnix = "${nonNixosGpuRoot + /setup.nix}";
          homemanager = inputs.home-manager;
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
            jq
          ];
          keep = {
            "$current_package" = true;
          };
          fake.external = [
            "nix"
            "nvidia-smi"
          ];
        };
      };
    in
    replaceVars (nonNixosGpuRoot + /non-nixos-gpu-biggs.service) { setupbash = getExe setupBash; };

  # On macOS, "admin" should be used instead of sudo.
  sudoersFile = writeText "10-bigolu" ''
    %sudo ALL=(ALL:ALL) NOPASSWD: ${getExe pkgs.run-as-admin}
    Defaults  env_keep += "TERMINFO"
    Defaults  env_keep += "PATH"
    Defaults  timestamp_timeout=30
  '';
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  _module.args = {
    pkgs = lib.mkForce (import ../../packages.nix { inherit system; });
    myUtils = import ../../utils.nix;
    pins = import ../../pins pkgs;
    inherit hasGui;
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
      "keyd/default.conf".source = projectRoot + /program-configs/keyd/default.conf;
      "udev/rules.d/99-keychron-launcher.rules".source =
        projectRoot + /program-configs/keychron-launcher/99-keychron-launcher.rules;
      "sudoers.d/10-bigolu".source = sudoersFile;
    };
  };

  systemd = {
    packages = [
      pkgs.keyd
    ]
    ++ optionals hasGui [
      (linkFarm "non-nixos-gpu-setup-units" {
        "lib/systemd/system/non-nixos-gpu-biggs.service" = nonNixosGpuService;
        "lib/systemd/system/non-nixos-gpu-biggs.path" = nonNixosGpuRoot + /non-nixos-gpu-biggs.path;
      })
    ];

    services = {
      keyd.wantedBy = [ "multi-user.target" ];
    };

    paths = optionalAttrs hasGui { non-nixos-gpu-biggs.wantedBy = [ "multi-user.target" ]; };
  };

  users = {
    groups.biggs.gid = 1000;
    users.biggs = {
      isNormalUser = true;
      uid = 1000;
      group = "biggs";
      home = "/home/biggs";
      createHome = true;
    };
  };
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users.biggs.imports = [ (import ../home/essentials { inherit hasGui hostName; }) ];
  };
}
