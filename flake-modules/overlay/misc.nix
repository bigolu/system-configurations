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
        ];
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
        # I'm adding general/bin for: trash, pbcopy
        wrapProgram $out/bin/nvim \
          --set TERMINFO_DIRS '${myTerminfoDatabase}/share/terminfo' \
          --set PARINIT 'rTbgqR B=.\,?'"'"'_A_a_@ Q=_s>|' \
          --prefix PATH : ${lib.escapeShellArg "${dependencies}/bin"} \
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
      # I want to run `darwin-rebuild switch` and only input my password once, but
      # homebrew, rightly, invalidates the sudo cache before it runs[1] so I have to
      # input my password again for subsequent steps in the rebuild. This script
      # allows ANY command to be run without a password, for the duration of the
      # specified command. It also runs the specified command as the user that
      # launched this script, i.e. SUDO_USER, and not root.
      #
      # [1]: https://github.com/Homebrew/brew/pull/17694/commits/2adf25dcaf8d8c66124c5b76b8a41ae228a7bb02

      if [[ "$1" == '--path' ]]; then
        PATH="$2:$PATH"
        shift 2
      fi

      temp="$(mktemp)"
      if uname | grep -q Linux; then
        group='sudo'
      else
        group='admin'
      fi
      printf "%%$group		ALL = (ALL) NOPASSWD: ALL\n" > "$temp"

      sudo chown --reference /etc/sudoers "$temp"
      sudo mv "$temp" /etc/sudoers.d/temp-config

      set +o errexit
      # sudo policy on Pop!_OS won't let me use --preserve-env=PATH
      sudo -u "$SUDO_USER" "$(which env)" "PATH=$PATH" "$@"
      exit_code=$?
      set -o errexit

      sudo rm /etc/sudoers.d/temp-config

      exit $exit_code
    '';
  };

  myFonts = final.symlinkJoin {
    name = "my-fonts";
    version = self.lib.formatDate self.lastModifiedDate;
    paths = with final; [
      monaspace
      (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
      fira-mono
    ];
  };
in
{
  inherit
    runAsAdmin
    myFonts
    # I'm renaming this to avoid rebuilds.
    myTerminfoDatabase
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

  shebang-runner = final.writeShellApplication {
    name = "shebang-runner";

    # So I don't have to specify bash as a dependency separately
    runtimeInputs = with final; [ bash ];

    text = ''
      # TODO: nix-shell sets the temporary directory environment variables. This is a
      # problem because cached-nix-shell caches the environment variables set by
      # nix-shell so when I execute the shell again, the temporary directory will not
      # exist which will break any programs that try to access it. To get around
      # this, I use this script as my shebang interpreter and then I unset the
      # variables. Maybe once the nix development environment logic is separated from
      # making a build debugging logic, this won't be an issue anymore[1]. Otherwise,
      # I should see if cached-nix-shell could allow users to specify variables that
      # shouldn't get cached.
      #
      # [1]: https://github.com/NixOS/nixpkgs/pull/330822
      unset TMPDIR TEMPDIR TMP TEMP

      exec ${final.bash}/bin/bash "$@"
    '';
  };
}
