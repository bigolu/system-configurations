{
  lib,
  pkgs,
  hasGui,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  inherit (lib) mkMerge mkIf;
  inherit (pkgs) myFonts;
in
mkMerge [
  (mkIf hasGui {
    home.packages = [ myFonts ];
  })
  (mkIf (isLinux && hasGui) {
    fonts.fontconfig.enable = true;
    # VS Code can't read my fonts from Nix despite them showing up in fontconfig so I
    # make a symlink to them from a location that VS Code _does_ read.
    xdg.dataFile."fonts".source = "${myFonts}/share/fonts";
  })
]
