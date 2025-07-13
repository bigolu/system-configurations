{
  pkgs,
  utils,
  ...
}:
let
  inherit (utils) projectRoot;
  inherit (pkgs) symlinkJoin makeWrapper skhd;

  dependencies = symlinkJoin {
    name = "skhd-dependencies";
    paths = with pkgs; [
      skhd
      yabai
      fish
      jq
      bashInteractive
    ];
  };

  skhdWithDependencies = symlinkJoin {
    name = "my-${skhd.name}";
    paths = [ skhd ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/skhd \
        --prefix PATH : ${dependencies}/bin \
        --prefix PATH : ${projectRoot + /dotfiles/skhd/bin}
    '';
  };
in
{
  services.skhd = {
    enable = true;
    package = skhdWithDependencies;
  };
}
