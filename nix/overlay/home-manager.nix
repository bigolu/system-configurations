# Adding these packages to pkgs so I can override them in the portable home config

{ utils, ... }:
final: _prev:
let
  inherit (final) writeShellApplication;
  inherit (final.stdenv) isLinux isDarwin;
  inherit (final.lib) makeBinPath fileset optionals;
  inherit (utils) projectRoot;

  system-config-sync = writeShellApplication {
    name = "system-config-sync";
    runtimeInputs = with final; [
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
          --flake "$1" \
          "''${@:2}" \
          |& nom
      else
        darwin-rebuild \
          switch \
          --flake "$1" \
          "''${@:2}" \
          |& nom
      fi
    '';
  };

  system-config-preview-sync = writeShellApplication {
    name = "system-config-preview-sync";
    runtimeInputs = with final; [
      nix
      nvd
    ];
    text = ''
      oldGenerationPath="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
      newGenerationPath="$(nix build --no-link --print-out-paths "$1")"
      nvd --color=never diff "$oldGenerationPath" "$newGenerationPath"
    '';
  };

  system-config-pull = writeShellApplication {
    name = "system-config-pull";
    runtimeInputs = with final; [
      coreutils
      gitMinimal
      less
      nix
    ];
    text = ''
      function exit_handler {
        if (($? != 0)); then
          echo 'Pull failed, run "system-config-pull" to try again.' >&2
        fi
        if [[ ''${did_stash:-} == true ]]; then
          git stash pop 1>/dev/null
        fi
      }
      trap exit_handler EXIT

      function direnv_local {
        nix-shell direnv/direnv-wrapper.bash direnv/local.bash "$@"
      }

      # TODO: So `mise` has access to `system-config-sync`. The problem is that
      # the system-* programs are not available in the package set so I can't
      # declare them as a dependency.
      PATH="${makeBinPath [ system-config-sync ]}:$PATH"

      cd "$1"

      if [[ -n "$(git status --porcelain)" ]]; then
        git stash --include-untracked --message 'Stashed for system pull' 1>/dev/null
        did_stash=true
      fi

      git fetch
      if [[ -n "$(git log 'HEAD..@{u}' --oneline)" ]]; then
        echo "$(echo 'Commits made since last pull:'$'\n'; git log '..@{u}')" | less
        direnv_local exec . git pull
        direnv_local exec . mise run sync
      else
        # Something probably went wrong so we're trying to pull again even
        # though there's nothing to pull. In which case, just sync.
        direnv_local exec . mise run sync
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
        with final;
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

        cd "$1"

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
                -e ${system-config-pull}/bin/system-config-pull "$1"
            fi
          else
            terminal-notifier \
              -title "Nix Darwin" \
              -message 'There are changes on the remote, click here to pull.' \
              -execute 'open -n -a Ghostty --args --config-default-files=false --config-file=${ghosttyConfigFile} --wait-after-command=true -e ${system-config-pull}/bin/system-config-pull'" $1"
          fi
        fi
      '';
    };

  update-reminder = writeShellApplication {
    name = "update-reminder";
    runtimeInputs =
      with final;
      [
        coreutils
        gitMinimal
      ]
      ++ (optionals isLinux [ libnotify ])
      ++ (optionals isDarwin [ terminal-notifier ]);
    text = ''
      cd "$1"
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
{
  homeManager = {
    inherit
      system-config-sync
      system-config-preview-sync
      system-config-pull
      remote-changes-check
      update-reminder
      ;
  };
}
