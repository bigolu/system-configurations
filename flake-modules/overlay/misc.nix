{
  inputs,
  lib,
  self,
  ...
}:
final: prev:
let
  inherit (final.stdenv) isLinux isDarwin;
  fs = lib.fileset;

  # ncurses doesn't come with wezterm's terminfo so I need to add it to the
  # database.
  myTerminfoDatabase = final.symlinkJoin {
    name = "my-terminfo-database";
    paths = [
      final.wezterm.terminfo
      final.ncurses
    ];
  };

  nightlyNeovimWithDependencies =
    let
      nightly = inputs.neovim-nightly-overlay.packages.${final.system}.default;
      dependencies = final.symlinkJoin {
        name = "neovim-dependencies";
        paths = with final; [
          # to format comments
          par

          # For the conform.nvim formatters 'trim_whitespace' and
          # 'squeeze_blanks' which require awk and cat respectively
          gawk
          coreutils-full
        ];
      };
      neovimBin = fs.toSource {
        root = self.lib.root + "/dotfiles/neovim/bin";
        fileset = self.lib.root + "/dotfiles/neovim/bin";
      };
      generalBin = fs.toSource {
        root = self.lib.root + "/dotfiles/general/bin";
        fileset = self.lib.root + "/dotfiles/general/bin";
      };
      generalMacosBin = fs.toSource {
        root = self.lib.root + "/dotfiles/general/bin-macos";
        fileset = self.lib.root + "/dotfiles/general/bin-macos";
      };
      neovimLinuxBin =
        let
          src = fs.toSource {
            root = self.lib.root + "/dotfiles/neovim/linux-bin";
            fileset = self.lib.root + "/dotfiles/neovim/linux-bin";
          };
        in
        final.runCommand "neovim-linux-bin" { } ''
          mkdir "$out"
          cp ${lib.escapeShellArg src}/wezterm.bash "$out/wezterm"
        '';
    in
    final.symlinkJoin {
      name = "my-${nightly.name}";
      paths = [ nightly ];
      buildInputs = [ final.makeWrapper ];
      postBuild = ''
        # TERMINFO: Neovim uses unibilium to discover term info entries
        # which is a problem for me because unibilium sets its terminfo
        # search path at build time so I'm setting the search path here.
        #
        # PARINIT: The par manpage recommends using this value if you want
        # to start using par, but aren't familiar with how par works so
        # until I learn more, I'll use this value.
        #
        # I'm adding general/bin for: conform, trash, pbcopy
        wrapProgram $out/bin/nvim \
          --set TERMINFO_DIRS '${myTerminfoDatabase}/share/terminfo' \
          --set PARINIT 'rTbgqR B=.\,?'"'"'_A_a_@ Q=_s>|' \
          --prefix PATH : ${lib.escapeShellArg "${dependencies}/bin"} \
          --prefix PATH : ${lib.escapeShellArg neovimBin} \
          --prefix PATH : ${lib.escapeShellArg generalBin} ${lib.strings.optionalString isDarwin "--prefix PATH : ${generalMacosBin}"} ${lib.strings.optionalString isLinux "--prefix PATH : ${neovimLinuxBin}"}
      '';
    };

  ripgrepAllWithDependencies =
    let
      dependencies = final.symlinkJoin {
        name = "ripgrep-all-dependencies";
        paths = with final; [
          xlsx2csv
          fastgron
          tesseract
          djvulibre
        ];
      };
      ripgrepBin = fs.toSource {
        root = self.lib.root + "/dotfiles/ripgrep/bin";
        fileset = self.lib.root + "/dotfiles/ripgrep/bin";
      };
    in
    final.symlinkJoin {
      inherit (prev.ripgrep-all) name;
      paths = [ prev.ripgrep-all ];
      buildInputs = [ final.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rga --prefix PATH : ${lib.escapeShellArg "${dependencies}/bin"} --prefix PATH : ${lib.escapeShellArg ripgrepBin}
      '';
    };
in
{
  # I'm renaming this to avoid rebuilds.
  inherit myTerminfoDatabase;

  neovim = nightlyNeovimWithDependencies;
  ripgrep-all = ripgrepAllWithDependencies;

  # TODO: The Determinate Systems Nix Installer installs a version of nix
  # that is higher than stable nix (pkgs.nix). Since there has been a
  # manifest version change between the two, I can't use stable nix. When
  # stable nix supports my manifest version, I should switch back to it.
  nix = final.nixVersions.latest;

  script-dependencies = lib.trivial.pipe (self.lib.root + "/scripts/dependencies.txt") [
    builtins.readFile
    (lib.strings.splitString "\n")
    (builtins.filter (line: line != ""))
    (names: map (name: final.${name}) names)
    (
      deps:
      final.symlinkJoin {
        name = "script-dependencies";
        paths = deps;
      }
    )
  ];
}
