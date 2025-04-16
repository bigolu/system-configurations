{
  lib,
  pkgs,
  configName,
  username,
  homeDirectory,
  isHomeManagerRunningAsASubmodule,
  repositoryDirectory,
  ...
}:
let
  inherit (lib)
    mkMerge
    mkIf
    hm
    getExe
    ;
  inherit (lib.attrsets) optionalAttrs;
  inherit (pkgs) writeShellApplication;
  inherit (pkgs.stdenv) isLinux isDarwin;

  update-reminder = writeShellApplication {
    name = "update-reminder";
    runtimeInputs = [ pkgs.homeManager.update-reminder ];
    text = "update-reminder ${repositoryDirectory}";
  };

  remote-changes-check = writeShellApplication {
    name = "remote-changes-check";
    runtimeInputs = [ pkgs.homeManager.remote-changes-check ];
    text = "remote-changes-check ${repositoryDirectory}";
  };
in
mkMerge [
  {
    # The `man` in nixpkgs is only intended to be used for NixOS, it doesn't work
    # properly on other OS's so I'm disabling it.
    #
    # home-manager issue: https://github.com/nix-community/home-manager/issues/432
    programs.man.enable = false;

    home = {
      # Since I'm not using the nixpkgs man, I have any packages I install their man
      # outputs so my system's `man` can find them.
      extraOutputsToInstall = [ "man" ];

      # This value determines the Home Manager release that your
      # configuration is compatible with. This helps avoid breakage
      # when a new Home Manager release introduces backwards
      # incompatible changes.
      #
      # You can update Home Manager without changing this value. See
      # the Home Manager release notes for a list of state version
      # changes in each release.
      stateVersion = "23.11";

      packages = with pkgs.homeManager; [
        (writeShellApplication {
          name = "system-config-pull";
          runtimeInputs = [ system-config-pull ];
          text = "system-config-pull ${repositoryDirectory}";
        })

        (writeShellApplication {
          name = "system-config-apply";
          runtimeInputs = [ system-config-apply ];
          text = ''
            system-config-apply ${repositoryDirectory}#${configName} "$@"
          '';
        })
      ];
    };
  }

  # These are all things that don't need to be done when home manager is being run as
  # a submodule inside of another system manager, like nix-darwin. They don't need to
  # be done because the outer system manager will do them.
  (optionalAttrs (!isHomeManagerRunningAsASubmodule) {
    home = {
      inherit username homeDirectory;

      packages = [
        (writeShellApplication {
          name = "system-config-preview";
          runtimeInputs = with pkgs.homeManager; [ system-config-preview ];
          text = "system-config-preview ${repositoryDirectory}#homeConfigurations.${configName}.activationPackage";
        })
      ];

      # Show me what changed everytime I switch generations e.g. version updates or
      # added/removed files.
      activation = {
        printGenerationDiff = hm.dag.entryAnywhere ''
          # On the first activation, there won't be an old generation.
          if [[ -n "''${oldGenPath+set}" ]] ; then
            ${getExe pkgs.nvd} --color=never diff $oldGenPath $newGenPath
          fi
        '';
      };
    };

    nix.package = pkgs.nix;

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    # Don't notify me of news updates when I switch generation. Ideally, I'd disable
    # news altogether since I don't read it. There's an issue open for making this an
    # option[1].
    #
    # [1]: https://github.com/nix-community/home-manager/issues/2033#issuecomment-1698406098
    news.display = "silent";
  })

  (mkIf isLinux {
    systemd.user = {
      services = {
        update-system-config-reminder = {
          Unit = {
            Description = "Reminder to update system-config dependencies";
          };
          Service = {
            ExecStart = getExe update-reminder;
          };
        };
        system-config-change-check = {
          Unit = {
            Description = "Check for home-manager changes on the remote";
          };
          Service = {
            Type = "oneshot";
            ExecStart = getExe remote-changes-check;
          };
        };
      };

      timers = {
        update-system-config-reminder = {
          Unit = {
            Description = "Reminder to update system-config dependencies";
          };
          Timer = {
            OnCalendar = "weekly";
            Persistent = true;
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
        system-config-change-check = {
          Unit = {
            Description = "Check for home-manager changes on the remote";
          };
          Timer = {
            OnCalendar = "daily";
            Persistent = true;
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
      };
    };
  })

  (mkIf isDarwin {
    launchd.agents = {
      update-system-config-reminder = {
        enable = true;
        config = {
          ProgramArguments = [ (getExe update-reminder) ];
          StartCalendarInterval = [
            # weekly
            {
              Weekday = 1;
              Hour = 0;
              Minute = 0;
            }
          ];
        };
      };
      system-config-change-check = {
        enable = true;
        config = {
          ProgramArguments = [ (getExe remote-changes-check) ];
          StartCalendarInterval = [
            # Since timers that go off when the computer is off never run, I try to
            # give myself more chances to see the message.
            # source: https://superuser.com/a/546353
            { Hour = 10; }
            { Hour = 16; }
            { Hour = 20; }
          ];
        };
      };
    };
  })
]
