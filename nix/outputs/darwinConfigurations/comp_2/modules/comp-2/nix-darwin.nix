{
  pkgs,
  lib,
  homeDirectory,
  username,
  ...
}:
let
  inherit (lib) getExe;
in
{
  configureLoginShellForNixDarwin = true;
  users.users.${username}.home = homeDirectory;

  system = {
    stateVersion = 4;

    activationScripts.postActivation.text = ''
      if [[ -e /run/current-system && (! /run/current-system -ef "$systemConfig") ]]; then
        printf '\e[1m[bigolu] Printing generation diff\e(B\e[m\n' >&2
        ${getExe pkgs.nvd} --color=never diff "$(readlink -f /run/current-system)" "$systemConfig"
      fi
    '';
  };
}
