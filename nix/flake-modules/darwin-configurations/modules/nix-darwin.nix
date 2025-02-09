{
  config,
  pkgs,
  lib,
  utils,
  configName,
  homeDirectory,
  username,
  repositoryDirectory,
  ...
}:
let
  inherit (utils) projectRoot;
  inherit (lib) fileset getExe;
  inherit (pkgs) writeShellApplication;

  system-config-preview = writeShellApplication {
    name = "system-config-preview";
    runtimeInputs = with pkgs; [
      nix
      coreutils
      nvd
    ];
    text = ''
      cd "${repositoryDirectory}"

      oldGenerationPath="$(readlink --canonicalize ${config.system.profile})"
      newGenerationPath="$(nix build --no-link --print-out-paths .#darwinConfigurations.${configName}.system)"

      printf 'Printing preview...\n'
      nvd --color=never diff "$oldGenerationPath" "$newGenerationPath"
    '';
  };

  system-config-apply = writeShellApplication {
    name = "system-config-apply";
    runtimeInputs = with pkgs; [
      nix
      coreutils
    ];
    text = ''
      cd "${repositoryDirectory}"
      ${config.system.profile}/sw/bin/darwin-rebuild switch \
        --flake "${repositoryDirectory}#${configName}" \
        "$@" |& nom
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
      trap 'echo "Pull failed, run \"mise run pull\" to try again."' ERR

      function direnv_wrapper {
        ./direnv/direnv-wrapper.bash direnv/local.bash "$@"
      }

      # TODO: So `mise` has access to `system-config-apply`, not a great solution
      PATH="${config.system.profile}/sw/bin:$PATH"
      cd "${repositoryDirectory}"

      rm -f ~/.local/state/nvim/*.log
      rm -f ~/.local/state/nvim/undo/*

      git fetch
      if [[ -n "$(git log 'HEAD..@{u}' --oneline)" ]]; then
          echo "$(echo 'Commits made since last pull:'$'\n'; git log '..@{u}')" | less

          if [[ -n "$(git status --porcelain)" ]]; then
              git stash --include-untracked --message 'Stashed for system pull'
          fi

          direnv_wrapper exec . git pull
          direnv_wrapper exec . mise run sync
      else
          # Something probably went wrong so we're trying to pull again even
          # though there's nothing to pull. In which case, just sync.
          direnv_wrapper exec . mise run sync
      fi

      # HACK:
      # https://stackoverflow.com/a/40473139
      rm -rf "$(/usr/local/bin/brew --prefix)/var/homebrew/locks"

      /usr/local/bin/brew update
      /usr/local/bin/brew upgrade --greedy
      /usr/local/bin/brew autoremove
      /usr/local/bin/brew cleanup
    '';
  };

  remote-changes-check =
    let
      ghosttyConfigFile = "${
        fileset.toSource {
          root = projectRoot + /dotfiles/ghostty;
          fileset = projectRoot + /dotfiles/ghostty/config;
        }
      }/config";
    in
    writeShellApplication {
      name = "remote-changes-check";

      runtimeInputs = with pkgs; [
        coreutils
        gitMinimal
        terminal-notifier
      ];

      text = ''
        log="$(mktemp --tmpdir 'nix_darwin_XXXXX')"
        exec 2>"$log" 1>"$log"
        trap 'terminal-notifier -title "Nix Darwin" -message "The check for changes failed :( Check the logs in $log"' ERR

        cd "${repositoryDirectory}"

        git fetch
        if [[ -n "$(git log 'HEAD..@{u}' --oneline)" ]]; then
          terminal-notifier \
            -title "Nix Darwin" \
            -message "There are changes on the remote, click here to pull." \
            -execute 'open -n -a Ghostty --args --config-default-files=false --config-file=${ghosttyConfigFile} --wait-after-command=true -e ${system-config-pull}/bin/system-config-pull'
        fi
      '';
    };
in
{
  configureLoginShellForNixDarwin = true;

  users.users.${username} = {
    home = homeDirectory;
  };

  environment = {
    systemPackages = [
      system-config-preview
      system-config-apply
      system-config-pull
    ];
  };

  system = {
    stateVersion = 4;

    activationScripts.postActivation.text = ''
      if [[ -e /run/current-system ]]; then
        printf '\e[36m┃ [bigolu] Printing generation diff ❯\e(B\e[m\n' >&2
        ${getExe pkgs.nvd} --color=never diff /run/current-system "$systemConfig"
      fi
    '';
  };

  launchd.user.agents.nix-darwin-change-check = {
    serviceConfig.RunAtLoad = false;

    serviceConfig.StartCalendarInterval = [
      # Since timers that go off when the computer is off never run, I try to
      # give myself more chances to see the message.
      # source: https://superuser.com/a/546353
      { Hour = 10; }
      { Hour = 16; }
      { Hour = 20; }
    ];

    command = ''${remote-changes-check}/bin/remote-changes-check'';
  };
}
