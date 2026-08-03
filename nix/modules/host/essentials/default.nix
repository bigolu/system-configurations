{
  _class,
  lib,
  config,
  myUtils,
  inputs,
  primaryUser,
  hostName,
  pkgs,
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
  inherit (myUtils) projectRoot programConfigRoot callIf;

  darwinAndSystem =
    let
      inherit (lib) optionals;
    in
    {
      home-manager.users.${primaryUser} = { config, ... }: {
        xdg.stateFile."bigolu/system-config-name".text = hostName;
        # For my shebang scripts
        home.packages = optionals config.fileWrapper.settings.editableInstall [ pkgs.bash ];
      };
    };
in
{
  homeManager =
    let
      gitignoreFilter =
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
        ./module-args.nix
        ./shell
        inputs.home-manager-file-wrapper.homeModules.file-wrapper
      ];

      home.stateVersion = "23.11";

      fileWrapper.settings = {
        editableInstall = true;

        relativePathRoot = {
          access = programConfigRoot;
        }
        // optionalAttrs inPureEvalMode {
          symlink = "${config.home.homeDirectory}/code/system-configurations/program-configs";
        };

        # Flakes have built-in gitignore support
        directoryFilter = callIf (!inPureEvalMode) gitignoreFilter;
      };
    };

  "" = {
    imports = [
      ./application-development
      ./fonts.nix
      ./home-manager.nix
      ./keyboard
      ./login-shell.nix
      ./module-args.nix
      ./nix.nix
      ./non-nixos-gpu-setup.nix
      ./sudo.nix
      darwinAndSystem
    ];

    system-manager.allowAnyDistro = true;
    users.users.${primaryUser}.isNormalUser = true;

    home-manager.users.${primaryUser} = { lib, ... }: {
      imports = [ ../essentials ];

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

  darwin = {
    imports = [
      ../speakers.nix
      ./application-development
      ./fonts.nix
      ./home-manager.nix
      ./homebrew.nix
      ./keyboard
      ./login-shell.nix
      ./module-args.nix
      ./nix.nix
      ./yabai.nix
      darwinAndSystem
    ];

    system = {
      inherit primaryUser;
      stateVersion = 7;

      # `AutoBoot` automatically turns the computer on when the lid opens. I
      # disable it to stop my computer from accidentally turning on while I'm
      # working on it.
      #
      # TODO: This option is marked internal
      nvram.variables."AutoBoot" = "%00";

      defaults = {
        dock = {
          autohide = true;
          mru-spaces = false;
        };

        LaunchServices = {
          LSQuarantine = false;
        };
      };

      activationScripts.applySystemSettingsImmediately.text = ''
        # Apply settings immediately so I don't have to logout/reboot.
        # source: https://medium.com/@zmre/nix-darwin-quick-tip-activate-your-preferences-f69942a93236
        sudo -u ${primaryUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

        # TODO: Some settings may not apply without doing this:
        # https://github.com/nix-darwin/nix-darwin/issues/658#issuecomment-1557604877
        killall Dock
      '';
    };

    programs = {
      bash.enable = false;
      zsh.enable = false;
    };
  };
}
.${toString _class}
