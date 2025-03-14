{
  lib,
  pkgs,
  configName,
  username,
  homeDirectory,
  isHomeManagerRunningAsASubmodule,
  utils,
  repositoryDirectory,
  ...
}:
let
  inherit (utils) projectRoot;
  inherit (lib)
    fileset
    mkMerge
    mkIf
    hm
    getExe
    optionals
    makeBinPath
    ;
  inherit (lib.attrsets) optionalAttrs;
  inherit (pkgs) writeShellApplication;
  inherit (pkgs.stdenv) isLinux isDarwin;

  # Scripts for switching generations and upgrading flake inputs.
  system-config-apply = writeShellApplication {
    name = "system-config-apply";
    runtimeInputs = with pkgs; [
      nix
      coreutils
      home-manager
      darwin-rebuild
    ];
    text = ''
      if [[ $(uname) == 'Linux' ]]; then
        home-manager \
          switch \
          -b backup \
          --flake ${repositoryDirectory}#${configName} \
          "$@" |& nom
      else
        darwin-rebuild \
          switch \
          --flake ${repositoryDirectory}#${configName} \
          "$@" |& nom
      fi
    '';
  };

  system-config-preview = writeShellApplication {
    name = "system-config-preview";
    runtimeInputs = with pkgs; [
      nix
      nvd
    ];
    text = ''
      oldGenerationPath="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
      newGenerationPath="$(
        nix build --no-link --print-out-paths \
          ${repositoryDirectory}#homeConfigurations.${configName}.activationPackage
      )"
      nvd --color=never diff "$oldGenerationPath" "$newGenerationPath"
    '';
  };

  system-config-pull = writeShellApplication {
    name = "system-config-pull";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      less
      nix
    ];
    text = ''
      function exit_handler {
        if (($? != 0)); then
          echo 'Pull failed, run "mise run pull" to try again.' >&2
        fi
        if [[ ''${did_stash:-} == true ]]; then
          git stash pop 1>/dev/null
        fi
      }
      trap exit_handler EXIT

      function direnv_wrapper {
        ./direnv/direnv-wrapper.bash direnv/local.bash "$@"
      }

      # TODO: So `mise` has access to `system-config-apply`. The problem is that
      # the system-* programs are not available in the package set so I can't
      # declare them as a dependency.
      PATH="${makeBinPath [ system-config-apply ]}:$PATH"

      cd ${repositoryDirectory}

      if [[ -n "$(git status --porcelain)" ]]; then
        git stash --include-untracked --message 'Stashed for system pull' 1>/dev/null
        did_stash=true
      fi

      git fetch
      if [[ -n "$(git log 'HEAD..@{u}' --oneline)" ]]; then
        echo "$(echo 'Commits made since last pull:'$'\n'; git log '..@{u}')" | less
        direnv_wrapper exec . git pull
        direnv_wrapper exec . mise run sync
      else
        # Something probably went wrong so we're trying to pull again even
        # though there's nothing to pull. In which case, just sync.
        direnv_wrapper exec . mise run sync
      fi

      if [[ $(uname) == 'Darwin' ]]; then
        # HACK:
        # https://stackoverflow.com/a/40473139
        rm -rf "$(/usr/local/bin/brew --prefix)/var/homebrew/locks"

        /usr/local/bin/brew update
        /usr/local/bin/brew upgrade --greedy
        /usr/local/bin/brew autoremove
        /usr/local/bin/brew cleanup
      fi
    '';
  };

  remote-changes-check =
    let
      ghosttyConfigDir = fileset.toSource {
        root = projectRoot + /dotfiles;
        fileset = projectRoot + /dotfiles/ghostty;
      };

      ghosttyConfigFile = "${
        fileset.toSource {
          root = projectRoot + /dotfiles/ghostty;
          fileset = projectRoot + /dotfiles/ghostty/config;
        }
      }/config";
    in
    writeShellApplication {
      name = "remote-changes-check";

      runtimeInputs =
        with pkgs;
        [
          coreutils
          gitMinimal
          # For ping
          toybox
        ]
        ++ (optionals isLinux [
          libnotify
          ghostty
        ])
        ++ (optionals isDarwin [ terminal-notifier ]);

      text = ''
        log="$(mktemp --tmpdir 'sys_config_XXXXX')"
        exec 2>"$log" 1>"$log"
        function failure_handler {
          if (($? == 0)); then
            return
          fi

          title='System Config'
          message="The check for changes failed. Check the logs in $log"
          if [[ $(uname) == 'Linux' ]]; then
            notify-send --app-name "$title" "$message"
          else
            terminal-notifier -title "$title" -message "$message"
          fi
        }
        trap failure_handler EXIT

        attempts=0
        while ! ping -c1 example.com && ((attempts < 60)); do
          attempts=$((attempts + 1))
          sleep 1
        done

        cd ${repositoryDirectory}

        git fetch
        if [[ -n "$(git log 'HEAD..@{u}' --oneline)" ]]; then
          if [[ $(uname) == 'Linux' ]]; then
            # TODO: I want to use action buttons on the notification, but it isn't
            # working. Instead, I assume that I want to pull if I click the
            # notification within one hour. Using `timeout` I can kill `notify-send`
            # once one hour passes.
            timeout_exit_code=124
            set +o errexit
            timeout 1h notify-send --wait --app-name 'Home Manager' \
              'There are changes on the remote, click here to pull.'
            exit_code=$?
            set -o errexit
            if (( exit_code != timeout_exit_code )); then
              XDG_CONFIG_HOME=${ghosttyConfigDir} ghostty \
                --wait-after-command=true \
                -e ${system-config-pull}/bin/system-config-pull
            fi
          else
            terminal-notifier \
              -title "Nix Darwin" \
              -message 'There are changes on the remote, click here to pull.' \
              -execute 'open -n -a Ghostty --args --config-default-files=false --config-file=${ghosttyConfigFile} --wait-after-command=true -e ${system-config-pull}/bin/system-config-pull'
          fi
        fi
      '';
    };

  update-reminder = writeShellApplication {
    name = "update-reminder";
    runtimeInputs =
      with pkgs;
      [
        coreutils
        gitMinimal
      ]
      ++ (optionals isLinux [ libnotify ])
      ++ (optionals isDarwin [ terminal-notifier ]);
    text = ''
      cd ${repositoryDirectory}
      if [[ $(git log --since="1 month ago") == *'deps:'* ]]; then
        exit
      fi

      if [[ $(uname) == 'Linux' ]]; then
        # TODO: I want to use action buttons on the notification, but it isn't
        # working. Instead, I assume that I want to pull if I click the notification
        # within one hour. Using `timeout` I can kill `notify-send` once one hour
        # passes.
        timeout_exit_code=124
        set +o errexit
        timeout 1h notify-send --wait --app-name 'System Configuration' \
          'Click here to update dependencies'
        exit_code=$?
        set -o errexit
        if (( exit_code != timeout_exit_code )); then
          xdg-open 'https://github.com/bigolu/system-configurations/actions/workflows/renovate.yaml'
        fi
      else
        terminal-notifier \
          -title 'System Configuration' \
          -message 'Click here to update dependencies' \
          -execute 'open "https://github.com/bigolu/system-configurations/actions/workflows/renovate.yaml"'
      fi
    '';
  };
in
mkMerge [
  # These are all things that don't need to be done when home manager is being run as
  # a submodule inside of another system manager, like nix-darwin. They don't need to
  # be done because the outer system manager will do them.
  (optionalAttrs (!isHomeManagerRunningAsASubmodule) {
    home = {
      inherit username homeDirectory;

      packages = [ system-config-preview ];

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

      packages = [
        system-config-apply
        system-config-pull
      ];
    };
  }

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
