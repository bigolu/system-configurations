{ pkgs, ... }: {
  devshell = {
    packages = [ pkgs.npins ];

    startup.npins.text = ''
      export NPINS_DIRECTORY="$PRJ_ROOT/nix/pins/npins"
    '';
  };
}
