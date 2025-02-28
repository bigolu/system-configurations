{
  config,
  pkgs,
  lib,
  configName,
  homeDirectory,
  username,
  repositoryDirectory,
  ...
}:
let
  inherit (lib) getExe;
  inherit (pkgs) writeShellApplication;

  system-config-preview = writeShellApplication {
    name = "system-config-preview";
    runtimeInputs = with pkgs; [
      nix
      coreutils
      nvd
    ];
    text = ''
      oldGenerationPath=${config.system.profile}
      newGenerationPath="$(
        nix build --no-link --print-out-paths \
          ${repositoryDirectory}#darwinConfigurations.${configName}.system
      )"
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
      ${config.system.profile}/sw/bin/darwin-rebuild switch \
        --flake ${repositoryDirectory}#${configName} \
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
      PATH="${config.system.profile}/sw/bin:$PATH"
      cd "${repositoryDirectory}"

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

      # HACK:
      # https://stackoverflow.com/a/40473139
      rm -rf "$(/usr/local/bin/brew --prefix)/var/homebrew/locks"

      /usr/local/bin/brew update
      /usr/local/bin/brew upgrade --greedy
      /usr/local/bin/brew autoremove
      /usr/local/bin/brew cleanup
    '';
  };
in
{
  configureLoginShellForNixDarwin = true;

  users.users.${username}.home = homeDirectory;

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
}
