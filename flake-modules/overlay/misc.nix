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

  runAsAdmin = final.writeShellApplication {
    name = "run-as-admin";
    runtimeInputs = with final; [ coreutils ];
    text = ''
      # WARNING: Don't copy this unless you understand the consequences. On a
      # multi-user machine this is probably a bad idea. I'm assuming that on a
      # personal, single-user, machine, this won't leave me any more vulnerable in
      # practice. Considering most of the sensitive stuff in my home directory
      # anyway[2]. You may be wondering why I have a sudo password at all. While it
      # won't help from a security standpoint, I do like having it as a confirmation
      # whenever I'm about to do something that operates on the system. This way if I
      # accidentally run something that modifies the system, when I only mean to
      # modify the user, I get a password prompt and that lets me know I'm probably
      # doing something wrong and save me from having to reinstall if that command
      # would have corrupted/removed anything.
      #
      # I want to run `darwin-rebuild switch` and only input my password once, but
      # homebrew, rightly, invalidates the sudo cache before it runs[1] so I have to
      # input my password again for subsequent steps in the rebuild. This script
      # allows ANY command to be run without a password, for the duration of the
      # specified command. It also runs the specified command as the user that
      # launched this script, i.e. SUDO_USER, and not root.
      #
      # [1]: https://github.com/Homebrew/brew/pull/17694/commits/2adf25dcaf8d8c66124c5b76b8a41ae228a7bb02
      # [2]: https://xkcd.com/1200/

      temp="$(mktemp)"
      printf '%%admin		ALL = (ALL) NOPASSWD: ALL\n' > "$temp"

      sudo chown --reference /etc/sudoers "$temp"
      sudo mv "$temp" /etc/sudoers.d/temp-config

      set +o errexit
      sudo -u "$SUDO_USER" "$@"
      exit_code=$?
      set -o errexit

      sudo rm /etc/sudoers.d/temp-config

      exit $exit_code
    '';
  };
in
{
  inherit
    # I'm renaming this to avoid rebuilds.
    myTerminfoDatabase
    runAsAdmin
    ;

  neovim = nightlyNeovimWithDependencies;
  ripgrep-all = ripgrepAllWithDependencies;

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
