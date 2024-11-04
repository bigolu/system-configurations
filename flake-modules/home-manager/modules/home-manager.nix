{
  config,
  lib,
  pkgs,
  specialArgs,
  ...
}:
let
  inherit (specialArgs)
    configName
    username
    homeDirectory
    isHomeManagerRunningAsASubmodule
    ;
  inherit (lib.attrsets) optionalAttrs;
  inherit (pkgs.stdenv) isLinux;

  # Scripts for switching generations and upgrading flake inputs.
  system-config-apply = pkgs.writeShellApplication {
    name = "system-config-apply";
    runtimeInputs = with pkgs; [ nix-output-monitor ];
    text = ''
      cd "${config.repository.directory}"
      ${config.home.profileDirectory}/bin/home-manager \
        switch \
        --flake "${config.repository.directory}#${configName}" \
        "$@" \
        |& nom

      # TODO: You shouldn't manage the system from home-manager. Ideally, I'd use
      # something like system-manager[1], but I don't think it works with
      # home-manager yet[2].
      #
      # Use --set-home to avoid sudo's warning that current user doesn't own the home
      # directory.
      #
      # [1]: https://github.com/numtide/system-manager
      # [2]: https://github.com/numtide/system-manager/issues/109

      PATH="${
        pkgs.lib.makeBinPath (
          with pkgs;
          [
            coreutils
            jq
          ]
        )
      }:$PATH"

      echo >&2 "[bigolu] Syncing nix-darwin's nix/cacert version with the system..."

      desired_store_paths=(${config.nix.package} ${pkgs.cacert})
      store_path_diff="$(comm -3 <(sudo --set-home nix profile list --json | jq --raw-output '.elements | keys[] as $k | .[$k].storePaths[]' | sort) <(printf '%s\n' "''${desired_store_paths[@]}" | sort))"
      if [[ -n "$store_path_diff" ]]; then
        sudo --set-home nix profile remove --all
        sudo --set-home nix profile install "''${desired_store_paths[@]}"

        # Restart the daemon so we use the daemon from the version of nix we just
        # installed
        systemctl restart nix-daemon.service

        # To avoid having root directly manipulate the store, explicitly set the
        # daemon.
        # Source: https://docs.lix.systems/manual/lix/stable/installation/multi-user.html#multi-user-mode
        while ! nix-store --store daemon -q --hash ${pkgs.stdenv.shell} &>/dev/null; do
          echo "waiting for nix-daemon" >&2
          sleep 0.5
        done
      fi
    '';
  };

  system-config-preview = pkgs.writeShellApplication {
    name = "system-config-preview";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      nix
    ];
    text = ''
      cd "${config.repository.directory}"

      oldGenerationPath="$(${config.home.profileDirectory}/bin/home-manager generations | head -1 | grep -E --only-matching '/nix.*$')"

      newGenerationPath="$(nix build --no-link --print-out-paths .#homeConfigurations.${configName}.activationPackage)"

      cyan='\033[1;0m'
      printf "%bPrinting switch preview...\n" "$cyan"
      nix store diff-closures "''$oldGenerationPath" "''$newGenerationPath"
    '';
  };

  system-config-pull = pkgs.writeShellApplication {
    name = "system-config-pull";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      less
      direnv
      nix
    ];
    text = ''
      trap 'echo "Pull failed, run \"just pull\" to try again."' ERR

      # TODO: So `just` has access to `system-config-apply`, not a great solution
      PATH="${config.home.profileDirectory}/bin:$PATH"
      cd "${config.repository.directory}"

      rm -f ~/.local/state/nvim/*.log
      rm -f ~/.local/state/nvim/undo/*

      git fetch
      if [[ -n "$(git log 'HEAD..@{u}' --oneline)" ]]; then
          echo "$(echo 'Commits made since last pull:'$'\n'; git log '..@{u}')" | less

          if [[ -n "$(git status --porcelain)" ]]; then
              git stash --include-untracked --message 'Stashed for system pull'
          fi

          direnv allow
          direnv exec "$PWD" nix-direnv-reload
          direnv exec "$PWD" git pull
          direnv exec "$PWD" just sync
      else
          # Something probably went wrong so we're trying to pull again even
          # though there's nothing to pull. In which case, just sync.
          direnv allow
          direnv exec "$PWD" nix-direnv-reload
          direnv exec "$PWD" just sync
      fi
    '';
  };

  remote-changes-check = pkgs.writeShellApplication {
    name = "remote-changes-check";
    runtimeInputs = with pkgs; [
      coreutils
      gitMinimal
      libnotify
    ];
    text = ''
      log="$(mktemp --tmpdir 'home_manager_XXXXX')"
      exec 2>"$log" 1>"$log"
      trap 'notify-send --app-name "Home Manager" "The check for changes failed :( Check the logs in $log"' ERR

      cd "${config.repository.directory}"

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
          flatpak run org.wezfurlong.wezterm --config 'default_prog={[[${system-config-pull}/bin/system-config-pull]]}' --config 'exit_behavior=[[Hold]]'
        fi
      fi
    '';
  };
in
lib.mkMerge [
  {
    # The `man` in nixpkgs is only intended to be used for NixOS, it doesn't work properly on
    # other OS's so I'm disabling it.
    #
    # home-manager issue: https://github.com/nix-community/home-manager/issues/432
    programs.man.enable = false;

    home = {
      # Since I'm not using the nixpkgs man, I have any packages I install their man outputs so my
      # system's `man` can find them.
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

      # Show me what changed everytime I switch generations e.g. version updates or added/removed files.
      activation = {
        printGenerationDiff = lib.hm.dag.entryAnywhere ''
          # On the first activation, there won't be an old generation.
          if [[ -n "''${oldGenPath+set}" ]] ; then
            nix store diff-closures $oldGenPath $newGenPath
          fi
        '';
      };
    };

    nix.package = pkgs.nix;

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    # Don't notify me of news updates when I switch generation. Ideally, I'd disable news altogether since I don't
    # read it:
    # issue: https://github.com/nix-community/home-manager/issues/2033#issuecomment-1698406098
    news.display = "silent";

    systemd = optionalAttrs isLinux {
      user = {
        services = {
          home-manager-delete-old-generations = {
            Unit = {
              Description = "Delete old generations of home-manager";
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${config.home.profileDirectory}/bin/home-manager expire-generations '-180 days'";
            };
          };
          home-manager-change-check = {
            Unit = {
              Description = "Check for home-manager changes on the remote";
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${remote-changes-check}/bin/remote-changes-check";
            };
          };
        };

        timers = {
          home-manager-delete-old-generations = {
            Unit = {
              Description = "Delete old generations of home-manager";
            };
            Timer = {
              OnCalendar = "monthly";
              Persistent = true;
            };
            Install = {
              WantedBy = [ "timers.target" ];
            };
          };
          home-manager-change-check = {
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
    };
  })
]
