{
  config,
  specialArgs,
  pkgs,
  ...
}:
let
  inherit (specialArgs)
    configName
    homeDirectory
    username
    repositoryDirectory
    ;

  system-config-preview = pkgs.writeShellApplication {
    name = "system-config-preview";
    runtimeInputs = with pkgs; [
      nix
      coreutils
    ];
    text = ''
      cd "${repositoryDirectory}"

      oldGenerationPath="$(readlink --canonicalize ${config.system.profile})"

      newGenerationPath="$(nix build --no-link --print-out-paths .#darwinConfigurations.${configName}.system)"

      cyan='\033[1;0m'
      printf "%bPrinting switch preview...\n" "$cyan"
      nix store diff-closures "$oldGenerationPath" "$newGenerationPath"
    '';
  };

  system-config-apply = pkgs.writeShellApplication {
    name = "system-config-apply";
    runtimeInputs = with pkgs; [
      nix
      nix-output-monitor
      coreutils
    ];
    text = ''
      cd "${repositoryDirectory}"

      oldGenerationPath="$(readlink --canonicalize ${config.system.profile})"

      ${config.system.profile}/sw/bin/darwin-rebuild switch --flake "${repositoryDirectory}#${configName}" "$@" |& nom

      newGenerationPath="$(readlink --canonicalize ${config.system.profile})"

      cyan='\033[1;0m'
      printf "%bPrinting generation diff...\n" "$cyan"
      nix store diff-closures "$oldGenerationPath" "$newGenerationPath"
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

      # HACK:
      # https://stackoverflow.com/a/40473139
      rm -rf "$(/usr/local/bin/brew --prefix)/var/homebrew/locks"

      /usr/local/bin/brew update
      /usr/local/bin/brew upgrade --greedy
      /usr/local/bin/brew autoremove
      /usr/local/bin/brew cleanup
    '';
  };

  remote-changes-check = pkgs.writeShellApplication {
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
        terminal-notifier -title "Nix Darwin" -message "There are changes on the remote, click here to pull." -execute '/usr/local/bin/wezterm --config "default_prog={[[${system-config-pull}/bin/system-config-pull]]}" --config "exit_behavior=[[Hold]]"'
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
