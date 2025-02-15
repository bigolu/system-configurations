{ inputs, utils }:
final: prev:
let
  inherit (inputs.nixpkgs.lib)
    fileset
    recursiveUpdate
    ;
  inherit (utils) projectRoot unstableVersion;

  neovimWithDependencies =
    let
      previousNeovim = prev.neovim;

      dependencies = final.symlinkJoin {
        pname = "neovim-dependencies";
        version = unstableVersion;
        paths = with final; [
          # to format comments
          par
        ];
      };

      wrappedNeovim = final.symlinkJoin {
        pname = "my-${previousNeovim.pname}";
        inherit (previousNeovim) version;
        paths = [ previousNeovim ];
        nativeBuildInputs = [ final.makeWrapper ];
        postBuild = ''
          # PARINIT: The par manpage recommends using this value if you want
          # to start using par, but aren't familiar with how par works so
          # until I learn more, I'll use this value.
          wrapProgram $out/bin/nvim \
            --set PARINIT 'rTbgqR B=.\,?'"'"'_A_a_@ Q=_s>|' \
            --prefix PATH : ${dependencies}/bin
        '';
      };
    in
    # Merge with the original package to retain attributes like meta
    recursiveUpdate previousNeovim wrappedNeovim;

  ripgrepAllWithDependencies =
    let
      dependencies = final.symlinkJoin {
        pname = "ripgrep-all-dependencies";
        version = unstableVersion;
        paths = with final; [
          xlsx2csv
          fastgron
          tesseract
          djvulibre
        ];
      };
      ripgrepBin = fileset.toSource {
        root = projectRoot + /dotfiles/ripgrep/bin;
        fileset = projectRoot + /dotfiles/ripgrep/bin;
      };
    in
    final.symlinkJoin {
      pname = "my-${prev.ripgrep-all.pname}";
      inherit (prev.ripgrep-all) version;
      paths = [ prev.ripgrep-all ];
      nativeBuildInputs = [ final.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rga \
          --prefix PATH : ${dependencies}/bin \
          --prefix PATH : ${ripgrepBin}
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
    pname = "my-fonts";
    version = unstableVersion;
    paths = with final; [
      nerd-fonts.symbols-only
      jetbrains-mono
    ];
  };

  speakerctl =
    let
      programName = "speakerctl";
      pythonEnv = final.python3.withPackages (
        pythonPackages: with pythonPackages; [
          pip
          python-kasa
          diskcache
          ipython
          platformdirs
          psutil
          types-psutil
          mypy
        ]
      );
    in
    final.writeShellApplication {
      name = programName;
      runtimeInputs = [ pythonEnv ];
      meta.mainProgram = programName;

      passthru.devShell = final.mkShellWrapperNoCC {
        packages = [ pythonEnv ];
        shellHook = ''
          export PYTHONPYCACHEPREFIX="$DIRENV_LAYOUT_DIR/python-cache"
          export MYPY_CACHE_DIR="$DIRENV_LAYOUT_DIR/mypy-cache"
        '';
      };

      text = ''
        python ${../../smart_plug/smart_plug.py} "$@"
      '';
    };

  bash-script =
    let
      initFile = final.writeTextFile {
        name = "init-file";
        text = ''
          set -o errexit
          set -o nounset
          set -o pipefail
          shopt -s nullglob
          shopt -s inherit_errexit
        '';
      };
    in
    final.writeShellApplication {
      name = "bash-script";
      meta.description = ''
        Bash with settings applied for running scripts non-interactively.
      '';
      runtimeInputs = [ final.bash ];
      text = ''
        exec bash --noprofile --norc --init-file ${initFile} "$@"
      '';
    };
in
{
  neovim = neovimWithDependencies;
  ripgrep-all = ripgrepAllWithDependencies;
  packagesToCache = final.lib.recurseIntoAttrs { inherit (final) gomod2nix; };
  nix-shell-interpreter = final.makeNixShellInterpreterWithoutTmp {
    interpreter = final.bash-script;
  };

  inherit
    runAsAdmin
    myFonts
    speakerctl
    bash-script
    ;
}
