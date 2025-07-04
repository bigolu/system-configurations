# Adding these packages to pkgs so I can override them in the portable home config

_: final: _prev:
let
  inherit (final) writeShellApplication;
  inherit (final.stdenv) isLinux isDarwin;
  inherit (final.lib) makeBinPath optionals;

  system-config-sync = writeShellApplication {
    name = "system-config-sync";
    runtimeInputs = with final; [
      nix
      home-manager
      darwin-rebuild
      nix-output-monitor
    ];
    text = ''
      if [[ $OSTYPE == linux* ]]; then
        home-manager \
          switch \
          -b backup \
          --flake "$1" \
          "''${@:2}" \
          |& nom
      else
        sudo darwin-rebuild \
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
      git
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

      function direnv_development {
        nix-shell direnv/direnv-wrapper.bash direnv/config/development.bash "$@"
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
        direnv_development exec . git pull
        direnv_development exec . mise run sync
      else
        # Something probably went wrong so we're trying to pull again even
        # though there's nothing to pull. In which case, just sync.
        direnv_development exec . mise run sync
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

  update-reminder = writeShellApplication {
    name = "update-reminder";
    runtimeInputs =
      with final;
      [
        coreutils
        git
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
  systemConfig = {
    inherit
      system-config-sync
      system-config-preview-sync
      system-config-pull
      update-reminder
      ;
  };
}
