{ pkgs, lib, ... }:
let
  inherit (lib) getExe';
  inherit (pkgs) coreutils;
  touch = getExe' coreutils "touch";
in
{
  devshell = {
    packages = with pkgs; [
      lefthook
      # TODO: Lefthook won't run unless git is present so maybe nixpkgs should make it
      # a dependency.
      git
    ];

    startup.lefthook.text = ''
      # We only need to do this once since lefthook reinstalls hooks automatically.
      if [[ ! -e "$DEV_SHELL_STATE/lefthook-installed" ]]; then
        lefthook install --force
        ${touch} "$DEV_SHELL_STATE/lefthook-installed"
      fi
    '';
  };
}
