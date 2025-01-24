{
  config,
  lib,
  pkgs,
  configName,
  username,
  homeDirectory,
  isHomeManagerRunningAsASubmodule,
  utils,
  ...
}:
let
  inherit (utils) projectRoot;
  inherit (lib) fileset mkMerge hm;
  inherit (lib.attrsets) optionalAttrs;
  inherit (pkgs) writeShellApplication;
  inherit (pkgs.stdenv) isLinux;

  # Scripts for switching generations and upgrading flake inputs.
  system-config-apply = writeShellApplication {
    name = "system-config-apply";
    text = ''
      cd "${config.repository.directory}"
      ${config.home.profileDirectory}/bin/home-manager \
        switch \
        --flake "${config.repository.directory}#${configName}" \
        "$@"
    '';
  };

  system-config-preview = writeShellApplication {
    name = "system-config-preview";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      nix
    ];
    text = ''
      cd "${config.repository.directory}"

      oldGenerationPath="$(
        ${config.home.profileDirectory}/bin/home-manager generations \
          | head -1 \
          | grep -E --only-matching '/nix.*$'
      )"

      newGenerationPath="$(
        nix build --no-link --print-out-paths \
          .#homeConfigurations.${configName}.activationPackage
      )"

      cyan='\033[1;0m'
      printf "%bPrinting preview...\n" "$cyan"
      nix store diff-closures "$oldGenerationPath" "$newGenerationPath"
      ${
        fileset.toSource {
          root = projectRoot + /dotfiles/nix/bin;
          fileset = projectRoot + /dotfiles/nix/bin/nix-closure-size-diff.bash;
        }
      }/nix-closure-size-diff.bash "$oldGenerationPath" "$newGenerationPath"
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

          ./scripts/direnv.bash exec . git pull
          ./scripts/direnv.bash exec . just sync
      else
          # Something probably went wrong so we're trying to pull again even
          # though there's nothing to pull. In which case, just sync.
          ./scripts/direnv.bash exec . just sync
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
            XDG_CONFIG_HOME=${ghosttyConfig} ghostty \
              --wait-after-command=true \
              -e ${system-config-pull}/bin/system-config-pull
          fi
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
            nix store diff-closures $oldGenPath $newGenPath
            ${
              fileset.toSource {
                root = projectRoot + /dotfiles/nix/bin;
                fileset = projectRoot + /dotfiles/nix/bin/nix-closure-size-diff.bash;
              }
            }/nix-closure-size-diff.bash $oldGenPath $newGenPath
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

    systemd = optionalAttrs isLinux {
      user = {
        services = {
          home-manager-delete-old-generations = {
            Unit = {
              Description = "Delete old generations of home-manager";
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${config.home.profileDirectory}/bin/home-manager expire-generations '-1 days'";
            };
          };
          home-manager-change-check = {
            Unit = {
              Description = "Check for home-manager changes on the remote";
            };
            Service = {
              Type = "oneshot";
              ExecStartPre = "/usr/bin/env sh -c 'until ping -c1 example.com; do sleep 1; done;'";
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
              OnCalendar = "weekly";
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
