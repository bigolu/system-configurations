{
  config,
  lib,
  pkgs,
  specialArgs,
  ...
}:
let
  inherit (specialArgs) isGui;
  inherit (pkgs.stdenv) isLinux;
  inherit (lib.lists) optionals;
in
lib.mkMerge [
  (lib.mkIf isGui {
    home.packages =
      with pkgs;
      [
        myFonts
      ]
      ++ optionals (isLinux && isGui) [
        inter
      ];
  })
  (lib.mkIf (isLinux && isGui) {
    fonts.fontconfig.enable = true;
    # Wezterm can't read my fonts from Nix despite the showing up in fontconfig so I copy all the Nix fonts to
    # $XDG_DATA_HOME/fonts. Wezterm also can't read the font when it is a symlink to the Nix store so I
    # dereference the symbolic links. I don't preserve the mode of the original files since they are read
    # only and I want to be able to remove everything in the directory before copying again.
    home.activation.fontSetup =
      lib.hm.dag.entryAfter
        # Must be after `installPackages` since that's when the fonts get installed.
        [ "installPackages" ]
        ''
          target_directory='${config.xdg.dataHome}/fonts'
          rm -rf "''$target_directory/*"
          cp --no-preserve=mode --recursive --dereference '${config.home.profileDirectory}/share/fonts/.' "''$target_directory"
        '';
  })
]
