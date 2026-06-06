{ pkgs, ... }:
{
  devshell = {
    packages = with pkgs; [
      lefthook
      # TODO: Lefthook won't run unless git is present so maybe nixpkgs should make it
      # a dependency.
      git
    ];
  };
}
