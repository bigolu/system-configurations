{
  pkgs,
  lib,
  utils,
  ...
}:
{
  services = {
    skhd = {
      enable = true;

      package =
        let
          # all programs transitively called from my skhdrc
          dependencies = pkgs.symlinkJoin {
            name = "skhd-dependencies";
            paths = with pkgs; [
              skhd
              yabai
              fish
              jq
              bashInteractive
            ];
          };
          skhdBin = lib.fileset.toSource {
            root = utils.projectRoot + /dotfiles/skhd/bin;
            fileset = utils.projectRoot + /dotfiles/skhd/bin;
          };
        in
        pkgs.symlinkJoin {
          name = "my-${pkgs.skhd.name}";
          paths = [ pkgs.skhd ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/skhd \
              --prefix PATH : ${dependencies}/bin \
              --prefix PATH : ${skhdBin}
          '';
        };
    };
  };
}
