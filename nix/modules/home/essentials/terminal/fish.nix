{ pkgs, lib, ... }:
let
  inherit (lib) getExe hm;
in
{
  home = {
    packages = with pkgs.fishPlugins; [
      pkgs.fish
      async-prompt
      direnv-shell-hooks
    ];

    activation.reloadFish = hm.dag.entryAfter [ "linkGeneration" ] ''
      ${getExe pkgs.fish} -c fish-reload
    '';
  };

  fileWrapper.xdg.configFile."fish/conf.d" = {
    source = "fish/conf.d";
    recursive = true;
  };
}
