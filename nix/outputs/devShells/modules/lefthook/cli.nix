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
      if [[ ! -e "$PRJ_DATA_DIR/lefthook-installed" ]]; then
        lefthook install --force
        ${touch} "$PRJ_DATA_DIR/lefthook-installed"
      fi
    '';
  };
}
