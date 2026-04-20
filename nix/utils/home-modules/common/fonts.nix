{
  lib,
  pkgs,
  hasGui,
  utils,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  inherit (lib) mkMerge mkIf;
  inherit (pkgs) symlinkJoin;
  inherit (utils) unstableVersion;

  myFonts = symlinkJoin {
    pname = "my-fonts";
    version = unstableVersion;
    paths = with pkgs; [
      nerd-fonts.symbols-only
      jetbrains-mono
    ];
  };
in
mkMerge [
  (mkIf hasGui {
    home.packages = [ myFonts ];
  })
  (mkIf (isLinux && hasGui) {
    fonts.fontconfig.enable = true;
    # VS Code can't read my fonts from Nix despite them showing up in fontconfig so I
    # make a symlink to them from a location that VS Code _can_ read.
    xdg.dataFile."fonts".source = "${myFonts}/share/fonts";
  })
]
