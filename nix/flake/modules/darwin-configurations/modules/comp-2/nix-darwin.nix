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

  system-config-preview-sync = writeShellApplication {
    name = "system-config-preview-sync";
    runtimeInputs = with pkgs; [
      nix
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
in
{
  configureLoginShellForNixDarwin = true;

  users.users.${username}.home = homeDirectory;

  environment.systemPackages = [
    system-config-preview-sync
  ];

  system = {
    stateVersion = 4;

    activationScripts.postActivation.text = ''
      if [[ -e /run/current-system ]]; then
        printf '\e[36m┃ [bigolu] Printing generation diff ❯\e(B\e[m\n' >&2
        ${getExe pkgs.nvd} --color=never diff "$(readlink -f /run/current-system)" "$systemConfig"
      fi
    '';
  };
}
