{
  pkgs,
  lib,
  utils,
  ...
}:
let
  inherit (lib) fileset;
  inherit (utils) projectRoot;
  inherit (pkgs) symlinkJoin makeWrapper skhd;

  # Programs called from skhdrc that are inside the package set
  dependenciesFromPkgs = symlinkJoin {
    name = "skhd-dependencies";
    paths = with pkgs; [
      skhd
      yabai
      fish
      jq
      bashInteractive
    ];
  };

  # Programs called from skhdrc that are inside this project
  dependenciesFromProject = fileset.toSource {
    root = projectRoot + /dotfiles/skhd/bin;
    fileset = projectRoot + /dotfiles/skhd/bin;
  };

  skhdWithDependencies = symlinkJoin {
    name = "my-${skhd.name}";
    paths = [ skhd ];
    buildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/skhd \
        --prefix PATH : ${dependenciesFromPkgs}/bin \
        --prefix PATH : ${dependenciesFromProject}
    '';
  };
in
{
  services.skhd = {
    enable = true;
    package = skhdWithDependencies;
  };
}
