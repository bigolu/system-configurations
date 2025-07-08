{ inputs, utils }:
final: prev:
let
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
    final.lib.recursiveUpdate previousNeovim wrappedNeovim;

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
    in
    final.symlinkJoin {
      pname = "my-${prev.ripgrep-all.pname}";
      inherit (prev.ripgrep-all) version;
      paths = [ prev.ripgrep-all ];
      nativeBuildInputs = [ final.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rga \
          --prefix PATH : ${dependencies}/bin \
          --prefix PATH : ${projectRoot + /dotfiles/ripgrep/bin}
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
      kernel="$(uname)"
      if [[ $kernel == 'Linux' ]]; then
        group='sudo'
      else
        group='admin'
      fi
      printf "%%$group		ALL = (ALL) NOPASSWD: ALL\n" > "$temp"

      sudo chown --reference /etc/sudoers "$temp"
      sudo mv "$temp" /etc/sudoers.d/temp-config

      set +o errexit
      # sudo policy on Pop!_OS won't let me use --preserve-env=PATH
      sudo -u "$SUDO_USER" "$(type -P env)" "PATH=$PATH" "$@"
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

      passthru = {
        devShell = final.mkShellNoCC {
          packages = [ pythonEnv ];
        };
        python = pythonEnv;
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
          # Prevent child Bash shells from loading these settings
          unset BASH_ENV
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
        BASH_ENV=${initFile} exec bash --noprofile --norc "$@"
      '';
    };

  cached-nix-shell =
    let
      # These are the files needed by packages.nix and nixpkgs.nix
      source =
        final.lib.pipe
          [
            /flake.nix
            /flake.lock
            /nix
          ]
          [
            (map (relativePath: projectRoot + relativePath))
            final.lib.fileset.unions
            (
              union:
              final.lib.fileset.toSource {
                root = projectRoot;
                fileset = union;
              }
            )
          ];
    in
    final.writeShellApplication {
      name = "cached-nix-shell";
      meta.description = ''
        A wrapper for cached-nix-shell that adds a nixpkgs entry to NIX_PATH before
        calling the real cached-nix-shell.
      '';
      text = ''
        # cached-nix-shell looks up nixpkgs on the nix path so it can use
        # nixpkgs.runCommandNoCC to run the script. You can also set the nixpkgs used
        # by nix-shell by using the -I flag in the script shebang, but I don't do
        # that since I would have to specify the path to nixpkgs.nix in every script.
        #
        # I intentionally set this variable through a wrapper and not through a
        # devShell to avoid breaking `comma`[1] in a development environment. If I
        # did set it, then comma would use this nixpkgs instead of the one for my
        # system. Even if I were ok with that, I didn't build an index for this
        # nixpkgs so comma wouldn't be able to use it anyway.
        #
        # [1]: https://github.com/nix-community/comma
        export NIX_PATH="nixpkgs=${source}/nix/nixpkgs.nix''${NIX_PATH:+:$NIX_PATH}"

        # To avoid specifying the package set path in every script's nix shebang, I
        # export a variable with the path.
        export NIX_PACKAGES=${source}/nix/packages.nix

        ${final.lib.getExe prev.cached-nix-shell} "$@"
      '';
    };
in
{
  neovim = neovimWithDependencies;
  ripgrep-all = ripgrepAllWithDependencies;
  nix-shell-interpreter = final.makeNixShellInterpreterWithoutTmp {
    interpreter = final.bash-script;
  };
  mkShellNoCC = prev.mkShellWrapper.override {
    # So we can override `mkShellNoCC` without causing infinite recursion
    inherit (prev) mkShellNoCC;
  };

  inherit (inputs.nixpkgs-mise.legacyPackages.${final.system}) mise;
  # This is usually broken on unstable
  inherit (inputs.nixpkgs-stable.legacyPackages.${final.system}) diffoscopeMinimal;

  inherit
    runAsAdmin
    myFonts
    speakerctl
    bash-script
    cached-nix-shell
    ;
}
