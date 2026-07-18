{ pkgs, utils, ... }:
let
  inherit (utils) programConfigRoot;
  inherit (pkgs) symlinkJoin makeWrapper skhd;

  dependencies = symlinkJoin {
    name = "skhd-dependencies";
    paths = with pkgs; [
      skhd
      yabai
      fish
      jq
      bash
    ];
  };

  skhdWithDependencies = symlinkJoin {
    name = "my-${skhd.name}";
    paths = [ skhd ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/skhd \
        --prefix PATH : ${dependencies}/bin \
        --prefix PATH : ${programConfigRoot + /skhd/bin}
    '';
  };
in
{
  services.skhd = {
    enable = true;
    package = skhdWithDependencies;
  };
}
