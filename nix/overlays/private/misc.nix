{ inputs, utils }:
final: prev:
let
  inherit (inputs) self;
  inherit (inputs.nixpkgs.lib) fileset optionalString optionalAttrs;
  inherit (final.stdenv) isDarwin isLinux;
  inherit (utils) projectRoot formatDate;

  neovimWithDependencies =
    let
      previousNeovim = prev.neovim;
      dependencies = final.symlinkJoin {
        name = "neovim-dependencies";
        paths = with final; [
          # to format comments
          par
        ];
      };
      generalBin = fileset.toSource {
        root = projectRoot + /dotfiles/general/bin;
        fileset = projectRoot + /dotfiles/general/bin;
      };
      generalMacosBin = fileset.toSource {
        root = projectRoot + /dotfiles/general/bin-macos;
        fileset = projectRoot + /dotfiles/general/bin-macos;
      };
    in
    final.symlinkJoin {
      pname = "my-${previousNeovim.pname}";
      inherit (previousNeovim) version;
      paths = [ previousNeovim ];
      buildInputs = [ final.makeWrapper ];
      postBuild = ''
        # PARINIT: The par manpage recommends using this value if you want
        # to start using par, but aren't familiar with how par works so
        # until I learn more, I'll use this value.
        #
        # I'm adding general/bin for: trash, pbcopy
        wrapProgram $out/bin/nvim \
          --set PARINIT 'rTbgqR B=.\,?'"'"'_A_a_@ Q=_s>|' \
          --prefix PATH : ${dependencies}/bin \
          --prefix PATH : ${generalBin} \
          ${optionalString isDarwin "--prefix PATH : ${generalMacosBin}"}
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
      ripgrepBin = fileset.toSource {
        root = projectRoot + /dotfiles/ripgrep/bin;
        fileset = projectRoot + /dotfiles/ripgrep/bin;
      };
    in
    final.symlinkJoin {
      inherit (prev.ripgrep-all) name;
      paths = [ prev.ripgrep-all ];
      buildInputs = [ final.makeWrapper ];
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
    name = "my-fonts";
    version = formatDate self.lastModifiedDate;
    paths = with final; [
      monaspace
      nerd-fonts.symbols-only
      fira-mono
    ];
  };

  plugctl =
    let
      exeName = "plugctl";
    in
    final.writeShellApplication {
      name = exeName;
      runtimeInputs = [
        (import ../../plugctl-python.nix final)
      ];
      meta.mainProgram = exeName;
      text = ''
        python ${../../../dotfiles/smart_plug/smart_plug.py} "$@"
      '';
    };

  speakerctl =
    let
      exeName = "speakerctl";
    in
    final.writeShellApplication {
      name = exeName;
      runtimeInputs = [ final.plugctl ];
      meta.mainProgram = exeName;
      text = ''
        plugctl plug "$@"
      '';
    };

  ci-bash = final.writeShellApplication {
    name = "ci-bash";
    runtimeInputs = [ final.bash ];
    text = ''
      exec bash \
        --noprofile \
        --norc \
        -o errexit \
        -o nounset \
        -o pipefail "$@"
    '';
  };
in
{
  neovim = neovimWithDependencies;
  ripgrep-all = ripgrepAllWithDependencies;
  packagesToCache = final.lib.recurseIntoAttrs (
    { inherit (final) gomod2nix; } // optionalAttrs isLinux { inherit (final) ghostty; }
  );
  nix-shell-interpreter = final.makeNixShellInterpreterWithoutTmp { interpreter = final.bash; };

  inherit
    runAsAdmin
    myFonts
    plugctl
    speakerctl
    ci-bash
    ;
}
