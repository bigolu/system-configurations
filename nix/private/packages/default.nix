{
  pins,
  outputs,
  private,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) concatStringsSep substring;
  inherit (private.utils) unstableVersion projectRoot;
  inherit (lib) optionalAttrs getExe;
  inherit (pkgs.stdenv) isLinux;

  filterPrograms =
    package: programsToKeep:
    let
      findFilters = map (program: "! -name '${program}'") programsToKeep;
      findFiltersAsString = concatStringsSep " " findFilters;
    in
    pkgs.symlinkJoin {
      name = "${package.name}-partial";
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        cd $out/bin
        find . ${findFiltersAsString} -type f,l -exec rm -f {} +
      '';
    };
in
# perf: To avoid fetching `pins` unnecessarily in CI, I don't use their overlays.
# This way, I only have to fetch a source if I actually use one of its packages.
pkgs
// outputs.packages
// pins.gomod2nix.outputs
// rec {
  inherit (pins.home-manager.outputs) home-manager;
  npins = pins.npins.outputs;

  inherit (pins.nix-darwin.outputs)
    darwin-rebuild
    darwin-option
    darwin-version
    darwin-uninstaller
    ;

  # This is usually broken on unstable
  inherit (pins.nixpkgs-stable.outputs) diffoscopeMinimal;

  nix-shell-interpreter = outputs.packages.nix-shell-interpreter.override {
    interpreter = bash-script;
  };

  mkShellNoCC = outputs.packages.mkShellWrapper.override {
    # So we can override `mkShellNoCC` without causing infinite recursion
    inherit (pkgs) mkShellNoCC;
  };

  dumpNixShellShebang = outputs.packages.dumpNixShellShebang.override {
    inherit (private) pkgs;
  };

  neovim =
    let
      oldNeovim = pkgs.neovim-unwrapped;

      dependencies = pkgs.symlinkJoin {
        pname = "neovim-dependencies";
        version = unstableVersion;
        # to format comments
        paths = [ pkgs.par ];
      };

      wrappedNeovim = pkgs.symlinkJoin {
        pname = "my-${oldNeovim.pname}";
        inherit (oldNeovim) version;
        paths = [ oldNeovim ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
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
    lib.recursiveUpdate oldNeovim wrappedNeovim;

  myVimPluginPack = pkgs.vimUtils.packDir {
    bigolu.start = with pkgs.vimPlugins; [
      camelcasemotion
      dial-nvim
      lazy-lsp-nvim
      mini-nvim
      nvim-lightbulb
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
      nvim-treesitter-endwise
      nvim-treesitter-textobjects
      nvim-ts-autotag
      splitjoin-vim
      treesj
      vim-abolish
      vim-matchup
      # For indentexpr
      vim-nix
      vim-sleuth

      # TODO: should be upstreamed to nixpkgs
      (pkgs.vimUtils.buildVimPlugin {
        pname = "vim-caser";
        version = pins.vim-caser.revision;
        src = pins.vim-caser;
      })
    ];
  };

  fishPlugins = pkgs.fishPlugins // {
    # TODO: They don't seem to be making releases anymore. I should check with the
    # author and possibly have nixpkgs track master instead.
    async-prompt = pkgs.fishPlugins.async-prompt.overrideAttrs (_old: {
      version = pins.fish-async-prompt.revision;
      src = pins.fish-async-prompt;
    });
  };

  partialPackages = pkgs.lib.recurseIntoAttrs (
    {
      xargs = filterPrograms pkgs.findutils [ "xargs" ];
      ps = filterPrograms pkgs.procps [ "ps" ];
      pkill = filterPrograms pkgs.procps [ "pkill" ];
      look = filterPrograms pkgs.util-linux [ "look" ];
      # toybox is a multi-call binary so we are going to delete everything besides the
      # toybox executable and the programs I need which are just symlinks to it.
      toybox = filterPrograms pkgs.toybox [
        "toybox"
        "tar"
        "hostname"
        "strings"
      ];
    }
    // optionalAttrs isLinux {
      # The pstree from psmisc is preferred on linux for some reason:
      # https://github.com/NixOS/nixpkgs/blob/3dc440faeee9e889fe2d1b4d25ad0f430d449356/pkgs/applications/misc/pstree/default.nix#L36C8-L36C8
      pstree = filterPrograms pkgs.psmisc [ "pstree" ];
    }
  );

  config-file-validator = pkgs.stdenv.mkDerivation {
    pname = "config-file-validator";
    version = "1.8.0";
    src = pins.${"config-file-validator-${if isLinux then "linux" else "darwin"}"};
    installPhase = ''
      mkdir -p $out/bin
      cp $src/validator $out/bin/
    '';
    meta = {
      platforms = [
        "x86_64-linux"
        "x86_64-darwin"
      ];
    };
  };

  # Normally I'd use overrideAttrs, but that wouldn't affect keyd-application-mapper
  keyd =
    let
      # TODO: I'm assuming that the first 10 characters is enough for it to be
      # unique.
      version = "2.5.0-${substring 0 10 pins.keyd.revision}";

      src = pins.keyd;

      pypkgs = pkgs.python3.pkgs;

      appMap = pypkgs.buildPythonApplication rec {
        pname = "keyd-application-mapper";
        inherit version src;
        format = "other";

        postPatch = ''
          substituteInPlace scripts/${pname} \
            --replace-fail /bin/sh ${pkgs.runtimeShell}
        '';

        propagatedBuildInputs = with pypkgs; [ xlib ];

        dontBuild = true;

        installPhase = ''
          install -Dm555 -t $out/bin scripts/${pname}
        '';

        meta.mainProgram = "keyd-application-mapper";
      };
    in
    pkgs.stdenv.mkDerivation {
      pname = "keyd";
      inherit version src;

      postPatch = ''
        substituteInPlace Makefile \
          --replace-fail /usr/local ""

        substituteInPlace keyd.service.in \
          --replace-fail @PREFIX@ $out
      '';

      installFlags = [ "DESTDIR=${placeholder "out"}" ];

      buildInputs = [ pkgs.systemd ];

      enableParallelBuilding = true;

      postInstall = ''
        ln -sf ${getExe appMap} $out/bin/${appMap.pname}
        rm -rf $out/etc

        # TODO: keyd only links the service if /run/systemd/system exists[1]. I
        # should see if this can be changed.
        #
        # [1]: https://github.com/rvaiya/keyd/blob/9c758c0e152426cab3972256282bc7ee7e2f808e/Makefile#L51
        mkdir -p $out/lib/systemd/system
        cp keyd.service.in $out/lib/systemd/system/keyd.service
      '';

      passthru.tests.keyd = pkgs.nixosTests.keyd;

      meta = with lib; {
        description = "Key remapping daemon for Linux";
        license = licenses.mit;
        maintainers = with maintainers; [ alfarel ];
        platforms = platforms.linux;
      };
    };

  ripgrep-all =
    let
      dependencies = pkgs.symlinkJoin {
        pname = "ripgrep-all-dependencies";
        version = unstableVersion;
        paths = with pkgs; [
          xlsx2csv
          fastgron
          tesseract
          djvulibre
        ];
      };
    in
    pkgs.symlinkJoin {
      pname = "my-${pkgs.ripgrep-all.pname}";
      inherit (pkgs.ripgrep-all) version;
      paths = [ pkgs.ripgrep-all ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rga \
          --prefix PATH : ${dependencies}/bin \
          --prefix PATH : ${projectRoot + /dotfiles/ripgrep/bin}
      '';
    };

  runAsAdmin = pkgs.writeShellApplication {
    name = "run-as-admin";
    runtimeInputs = [ pkgs.coreutils ];
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

  myFonts = pkgs.symlinkJoin {
    pname = "my-fonts";
    version = unstableVersion;
    paths = with pkgs; [
      nerd-fonts.symbols-only
      jetbrains-mono
    ];
  };

  speakerctl =
    let
      programName = "speakerctl";
      pythonEnv = pkgs.python3.withPackages (
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
    pkgs.writeShellApplication {
      name = programName;
      runtimeInputs = [ pythonEnv ];
      meta.mainProgram = programName;

      passthru = {
        devShell = pkgs.mkShellNoCC {
          packages = [ pythonEnv ];
        };
        python = pythonEnv;
      };

      text = ''
        python ${projectRoot + /smart_plug/smart_plug.py} "$@"
      '';
    };

  bash-script =
    let
      initFile = pkgs.writeTextFile {
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
    pkgs.writeShellApplication {
      name = "bash-script";
      meta.description = ''
        Bash with settings applied for running scripts non-interactively.
      '';
      runtimeInputs = [ pkgs.bash ];
      text = ''
        BASH_ENV=${initFile} exec bash --noprofile --norc "$@"
      '';
    };

  cached-nix-shell = pkgs.writeShellApplication {
    name = "cached-nix-shell";
    meta.description = ''
      A wrapper for cached-nix-shell that adds a nixpkgs entry to NIX_PATH before
      calling the real cached-nix-shell.
    '';
    text = ''
      # The nixpkgs entry on the NIX_PATH is used for two things:
      #   - nixpkgs.runCommandCC is used to run a shebang script
      #   - The packages listed with -p/--packages are considered attribute
      #     names in nixpkgs
      #
      # I intentionally set this variable through a wrapper and not
      # through a dev shell to avoid breaking `comma`[1] in a development
      # environment. If I did set it, then comma would use this nixpkgs
      # instead of the one for my system. Even if I were ok with that, I
      # didn't build an index for this nixpkgs so comma wouldn't be able to
      # use it anyway.
      #
      # [1]: https://github.com/nix-community/comma
      if [[ -n ''${NIX_SHEBANG_NIXPKGS:-} ]]; then
        export NIX_PATH="nixpkgs=$NIX_SHEBANG_NIXPKGS''${NIX_PATH:+:$NIX_PATH}"
      fi

      ${
        getExe (
          pkgs.cached-nix-shell.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./fix-trace.patch ];
          })
        )
      } "$@"
    '';
  };
}
