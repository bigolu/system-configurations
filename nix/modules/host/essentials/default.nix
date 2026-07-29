let
  nixRoot = ../../..;
  utils = import (nixRoot + /utils.nix);
  pinsFunction = import (nixRoot + /pins);
in
{
  home =
    { hasGui, hostName }:
    {
      pkgs,
      lib,
      inputs,
      config,
      repositoryDirectory,
      ...
    }:
    let
      inherit (builtins) storeDir;
      inherit (lib)
        optionalAttrs
        inPureEvalMode
        isPath
        cleanSourceWith
        hasPrefix
        ;
      inherit (utils) projectRoot callIf;

      directoryFilter =
        let
          # PERF: As per the documentation[1], we memoize this.
          #
          # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
          filter = inputs.gitignore.lib.gitignoreFilterWith { basePath = projectRoot; };
        in
        stringOrPath:
        cleanSourceWith {
          inherit filter;
          # Clean source won't accept a string
          src =
            if (isPath stringOrPath || hasPrefix storeDir stringOrPath) then
              stringOrPath
            else
              /. + stringOrPath;
        };
    in
    {
      imports = [
        ./home-manager/home.nix
        ./terminal-home
        inputs.home-manager-file-wrapper.homeModules.file-wrapper
      ];

      _module.args = {
        inherit hasGui hostName utils;
        repositoryDirectory = "${config.home.homeDirectory}/code/system-configurations";
        pins = pinsFunction pkgs;
      };

      fileWrapper.settings = {
        editableInstall = true;

        relativePathRoot = {
          access = projectRoot + /program-configs;
        }
        // optionalAttrs inPureEvalMode { symlink = "${repositoryDirectory}/program-configs"; };

        # Flakes have built-in gitignore support
        directoryFilter = callIf (!inPureEvalMode) directoryFilter;
      };
    };

  system =
    {
      system,
      hostName,
      hasGui,
    }:
    {
      pkgs,
      lib,
      primaryUser,
      ...
    }:
    {
      imports = [
        (import ./home-manager/darwin-system.nix "nixos")
        ./application-development/darwin-system.nix
        ./application-development/system.nix
        ./fonts-darwin-system.nix
        ./general-darwin-system.nix
        ./keyboard/system.nix
        ./login-shell/darwin-system.nix
        ./nix/darwin-system.nix
        ./non-nixos-gpu-setup-system.nix
        ./sudo-system.nix
      ];

      _module.args = {
        pkgs = lib.mkForce (import (nixRoot + /packages.nix) { inherit system; });
        myUtils = utils;
        pins = pinsFunction pkgs;
        inherit hasGui hostName;
      };

      system-manager.allowAnyDistro = true;
      nixpkgs.hostPlatform = system;
      users.users.${primaryUser}.isNormalUser = true;

      home-manager.users.${primaryUser} = { lib, ... }: {
        imports = [ (utils.modules.home.essentials { inherit hasGui hostName; }) ];

        home = {
          # TODO: I'm only doing this because Pop!_OS doesn't come with it by
          # default, but I think it should.
          packages = [ pkgs.wl-clipboard ];

          # These services need to be reloaded after their config files are
          # installed and I think system-manager links files in /etc before
          # calling home-manager so `entryAnywhere` should be fine.
          #
          # TODO: I'd rather set `restartTriggers` on the
          # `systemd-{udevd,sysctl}` services, but my distro makes those
          # services and if I set <service>.`restartTriggers`, system-manager
          # replaces the entire service definition.
          activation.restartSystemServices = lib.hm.dag.entryAnywhere ''
            /usr/bin/sudo /usr/bin/udevadm control --reload-rules
            /usr/bin/sudo /usr/bin/udevadm trigger

            ${pkgs.moreutils}/bin/chronic /usr/bin/sudo /usr/sbin/sysctl -p --system
          '';
        };
      };
    };

  darwin = { primaryUser, ... }: {
    imports = with utils.modules.darwin; [
      (import ./home-manager/darwin-system.nix "darwin")
      ./application-development/darwin-system.nix
      ./fonts-darwin-system.nix
      ./general-darwin-system.nix
      ./homebrew-darwin.nix
      ./keyboard/darwin.nix
      ./login-shell/darwin-system.nix
      ./login-shell/darwin.nix
      ./mac-os-system-settings-darwin.nix
      ./nix/darwin
      ./nix/darwin-system.nix
      ./skhd-darwin.nix
      ./yabai-darwin.nix
      speakers
    ];

    _module.args = { inherit utils; };

    system = {
      inherit primaryUser;
      stateVersion = 4;
    };

    programs = {
      bash.enable = false;
      zsh.enable = false;
    };
  };
}
