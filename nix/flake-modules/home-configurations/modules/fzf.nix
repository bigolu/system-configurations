{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs) buildEnv;
  inherit (lib) hm;
  # TODO: v0.58 is buggy for me. I'm not overriding fzf in an overlay because that
  # would cause too many rebuilds. I'm fine with tools dependent on fzf using v0.58.
  inherit (inputs.nixpkgs-stable.legacyPackages.${pkgs.system}) fzf;

  fzfWithoutShellConfig = buildEnv {
    name = "fzf-without-shell-config";
    paths = [ fzf ];
    pathsToLink = [
      "/bin"
      "/share/man"
    ];
  };
in
{
  home.packages = [
    fzfWithoutShellConfig
  ];

  repository.symlink.xdg.executable."fzf" = {
    source = "fzf/bin";
    recursive = true;
  };

  home.activation.fzfSetup = hm.dag.entryAfter [ "writeBoundary" ] ''
    history_file="''${XDG_DATA_HOME:-$HOME/.local/share}/fzf/fzf-history.txt"
    mkdir -p "$(dirname "$history_file")"
    touch "$history_file"
  '';
}
