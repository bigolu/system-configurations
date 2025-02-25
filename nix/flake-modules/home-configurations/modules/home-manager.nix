{
  config,
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
    ;
  inherit (lib.attrsets) optionalAttrs;
  inherit (pkgs) writeShellApplication;
  inherit (pkgs.stdenv) isLinux isDarwin;

  # Scripts for switching generations and upgrading flake inputs.
  system-config-apply = writeShellApplication {
    name = "system-config-apply";
    text = ''
      ${config.home.profileDirectory}/bin/home-manager \
        switch \
        --flake ${repositoryDirectory}#${configName} \
        "$@" |& nom
    '';
  };

  system-config-preview = writeShellApplication {
    name = "system-config-preview";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
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
      direnv
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

      # TODO: So `mise` has access to `system-config-apply`, not a great solution
      PATH="${config.home.profileDirectory}/bin:$PATH"
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
    '';
  };

  remote-changes-check =
    let
      ghosttyConfig = fileset.toSource {
        root = projectRoot + /dotfiles;
        fileset =
          if isLinux then
            (projectRoot + /dotfiles/ghostty)
          else
            fileset.difference (projectRoot + /dotfiles/ghostty) (projectRoot + /dotfiles/ghostty/linux-config);
      };
    in
    writeShellApplication {
      name = "remote-changes-check";

      runtimeInputs = with pkgs; [
        coreutils
        gitMinimal
        libnotify
        ghostty
      ];

      text = ''
        log="$(mktemp --tmpdir 'home_manager_XXXXX')"
        exec 2>"$log" 1>"$log"
        function failure_handler {
          if (($? == 0)); then
            return
          fi
          notify-send --app-name 'Home Manager' "The check for changes failed. Check the logs in $log"
        }
        trap failure_handler EXIT

        cd ${repositoryDirectory}

        git fetch
        if [[ -n "$(git log 'HEAD..@{u}' --oneline)" ]]; then
          # TODO: I want to use action buttons on the notification, but it isn't
          # working.
          #
          # TODO: With `--wait`, `notify-send` only exits if the x button is
          # clicked. I assume that I want to pull if I click the x button
          # within one hour. Using `timeout` I can kill `notify-send` once one
          # hour passes.  This behavior isn't correct based on the `notify-send`
          # manpage, not sure if the bug is with `notify-send` or my desktop
          # environment, COSMIC.
          timeout_exit_code=124
          set +o errexit
          timeout 1h notify-send --wait --app-name 'Home Manager' \
            'There are changes on the remote. To pull, click the "x" button now or after the notification has been dismissed.'
          exit_code=$?
          set -o errexit
          if (( exit_code != timeout_exit_code )); then
            XDG_CONFIG_HOME=${ghosttyConfig} ghostty \
              --wait-after-command=true \
              -e ${system-config-pull}/bin/system-config-pull
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
        # working.
        #
        # TODO: With `--wait`, `notify-send` only exits if the x button is
        # clicked. I assume that I want to pull if I click the x button
        # within one hour. Using `timeout` I can kill `notify-send` once one
        # hour passes.  This behavior isn't correct based on the `notify-send`
        # manpage, not sure if the bug is with `notify-send` or my desktop
        # environment, COSMIC.
        timeout_exit_code=124
        set +o errexit
        timeout 1h notify-send --wait --app-name 'System Configuration' \
          'To update dependencies, click the "x" button now or after the notification has been dismissed.'
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
    };
  }

  (mkIf isLinux {
    systemd.user.services.update-system-config-reminder = {
      Unit = {
        Description = "Reminder to update system-config dependencies";
      };
      Service = {
        ExecStart = getExe update-reminder;
      };
    };
    systemd.user.timers.update-system-config-reminder = {
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
  })

  (mkIf isDarwin {
    launchd.agents.update-system-config-reminder = {
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
  })

  # These are all things that don't need to be done when home manager is being run as
  # a submodule inside of another system manager, like nix-darwin. They don't need to
  # be done because the outer system manager will do them.
  (optionalAttrs (!isHomeManagerRunningAsASubmodule) {
    home = {
      # Home Manager needs a bit of information about you and the
      # paths it should manage.
      inherit username homeDirectory;

      packages = [
        system-config-preview
        system-config-apply
        system-config-pull
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

    systemd.user = optionalAttrs isLinux {
      services.home-manager-change-check = {
        Unit = {
          Description = "Check for home-manager changes on the remote";
        };
        Service = {
          Type = "oneshot";
          ExecStartPre = "/usr/bin/env sh -c 'until ping -c1 example.com; do sleep 1; done;'";
          ExecStart = "${remote-changes-check}/bin/remote-changes-check";
        };
      };

      timers.home-manager-change-check = {
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
  })
]
