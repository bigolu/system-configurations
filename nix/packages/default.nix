# This package set is used for system configurations and nix shebang scripts. It's
# useful to put them all together so I can override packages.
{
  inputs,
  outputs,
  packages,
  lib,
  nixpkgs,
  utils,
  ...
}:
let
  inherit (builtins) concatStringsSep substring;
  inherit (utils) unstableVersion projectRoot;
  inherit (lib) optionalAttrs getExe recursiveUpdate;
  inherit (nixpkgs.stdenv) isLinux;

  filterPrograms =
    package: programsToKeep:
    let
      findFilters = map (program: "! -name '${program}'") programsToKeep;
      findFiltersAsString = concatStringsSep " " findFilters;
    in
    nixpkgs.symlinkJoin {
      name = "${package.name}-partial";
      paths = [ package ];
      nativeBuildInputs = [ nixpkgs.makeWrapper ];
      postBuild = ''
        cd $out/bin
        find . ${findFiltersAsString} -type f,l -exec rm -f {} +
      '';
    };
in
# perf: To avoid fetching inputs unnecessarily in CI, I don't use their overlays.
# This way, I only have to fetch a source if I actually use one of its packages.
nixpkgs
// outputs.packages
// inputs.gomod2nix.outputs
// rec {
  inherit (inputs.home-manager.outputs) home-manager;
  npins = inputs.npins.outputs;

  inherit (inputs.nix-darwin.outputs)
    darwin-rebuild
    darwin-option
    darwin-version
    darwin-uninstaller
    ;

  # This is usually broken on unstable
  inherit (inputs.nixpkgs-stable.outputs) diffoscopeMinimal;

  nix-shell-interpreter = outputs.packages.nix-shell-interpreter.override {
    interpreter = bash-script;
  };

  mkShellNoCC = outputs.packages.mkShellWrapper.override {
    # So we can override `mkShellNoCC` without causing infinite recursion
    inherit (nixpkgs) mkShellNoCC;
  };

  dumpNixShellShebang = outputs.packages.dumpNixShellShebang.override {
    pkgs = packages;
  };

  neovim =
    let
      oldNeovim = nixpkgs.neovim-unwrapped;

      dependencies = nixpkgs.symlinkJoin {
        pname = "neovim-dependencies";
        version = unstableVersion;
        # to format comments
        paths = [ nixpkgs.par ];
      };

      wrappedNeovim = nixpkgs.symlinkJoin {
        pname = "my-${oldNeovim.pname}";
        inherit (oldNeovim) version;
        paths = [ oldNeovim ];
        nativeBuildInputs = [ nixpkgs.makeWrapper ];
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

  myVimPluginPack = nixpkgs.vimUtils.packDir {
    bigolu.start = with nixpkgs.vimPlugins; [
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
      (nixpkgs.vimUtils.buildVimPlugin {
        pname = "vim-caser";
        version = inputs.vim-caser.revision;
        src = inputs.vim-caser;
      })
    ];
  };

  fishPlugins = nixpkgs.fishPlugins // {
    # TODO: They don't seem to be making releases anymore. I should check with the
    # author and possibly have nixpkgs track master instead.
    async-prompt = nixpkgs.fishPlugins.async-prompt.overrideAttrs (_old: {
      version = inputs.fish-async-prompt.revision;
      src = inputs.fish-async-prompt;
    });
  };

  partialPackages = nixpkgs.lib.recurseIntoAttrs (
    {
      xargs = filterPrograms nixpkgs.findutils [ "xargs" ];
      ps = filterPrograms nixpkgs.procps [ "ps" ];
      pkill = filterPrograms nixpkgs.procps [ "pkill" ];
      look = filterPrograms nixpkgs.util-linux [ "look" ];
      # toybox is a multi-call binary so we are going to delete everything besides the
      # toybox executable and the programs I need which are just symlinks to it.
      toybox = filterPrograms nixpkgs.toybox [
        "toybox"
        "tar"
        "hostname"
        "strings"
      ];
    }
    // optionalAttrs isLinux {
      # The pstree from psmisc is preferred on linux for some reason:
      # https://github.com/NixOS/nixpkgs/blob/3dc440faeee9e889fe2d1b4d25ad0f430d449356/pkgs/applications/misc/pstree/default.nix#L36C8-L36C8
      pstree = filterPrograms nixpkgs.psmisc [ "pstree" ];
    }
  );

  config-file-validator = nixpkgs.stdenv.mkDerivation {
    pname = "config-file-validator";
    version = "1.8.0";
    src = inputs.${"config-file-validator-${if isLinux then "linux" else "darwin"}"};
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
      version = "2.5.0-${substring 0 10 inputs.keyd.revision}";

      src = inputs.keyd;

      pypkgs = nixpkgs.python3.pkgs;

      appMap = pypkgs.buildPythonApplication rec {
        pname = "keyd-application-mapper";
        inherit version src;
        format = "other";

        postPatch = ''
          substituteInPlace scripts/${pname} \
            --replace-fail /bin/sh ${nixpkgs.runtimeShell}
        '';

        propagatedBuildInputs = with pypkgs; [ xlib ];

        dontBuild = true;

        installPhase = ''
          install -Dm555 -t $out/bin scripts/${pname}
        '';

        meta.mainProgram = "keyd-application-mapper";
      };
    in
    nixpkgs.stdenv.mkDerivation {
      pname = "keyd";
      inherit version src;

      postPatch = ''
        substituteInPlace Makefile \
          --replace-fail /usr/local ""

        substituteInPlace keyd.service.in \
          --replace-fail @PREFIX@ $out
      '';

      installFlags = [ "DESTDIR=${placeholder "out"}" ];

      buildInputs = [ nixpkgs.systemd ];

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

      passthru.tests.keyd = nixpkgs.nixosTests.keyd;

      meta = with lib; {
        description = "Key remapping daemon for Linux";
        license = licenses.mit;
        maintainers = with maintainers; [ alfarel ];
        platforms = platforms.linux;
      };
    };

  ripgrep-all =
    let
      dependencies = nixpkgs.symlinkJoin {
        pname = "ripgrep-all-dependencies";
        version = unstableVersion;
        paths = with nixpkgs; [
          xlsx2csv
          fastgron
          tesseract
          djvulibre
        ];
      };
    in
    nixpkgs.symlinkJoin {
      pname = "my-${nixpkgs.ripgrep-all.pname}";
      inherit (nixpkgs.ripgrep-all) version;
      paths = [ nixpkgs.ripgrep-all ];
      nativeBuildInputs = [ nixpkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/rga \
          --prefix PATH : ${dependencies}/bin \
          --prefix PATH : ${projectRoot + /dotfiles/ripgrep/bin}
      '';
    };

  runAsAdmin = nixpkgs.writeShellApplication {
    name = "run-as-admin";
    runtimeInputs = [ nixpkgs.coreutils ];
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

  myFonts = nixpkgs.symlinkJoin {
    pname = "my-fonts";
    version = unstableVersion;
    paths = with nixpkgs; [
      nerd-fonts.symbols-only
      jetbrains-mono
    ];
  };

  speakerctl =
    let
      programName = "speakerctl";
      pythonEnv = nixpkgs.python3.withPackages (
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
    nixpkgs.writeShellApplication {
      name = programName;
      runtimeInputs = [ pythonEnv ];
      meta.mainProgram = programName;

      passthru = {
        devShell = nixpkgs.mkShellNoCC {
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
      initFile = nixpkgs.writeTextFile {
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
    nixpkgs.writeShellApplication {
      name = "bash-script";
      meta.description = ''
        Bash with settings applied for running scripts non-interactively.
      '';
      runtimeInputs = [ nixpkgs.bash ];
      text = ''
        BASH_ENV=${initFile} exec bash --noprofile --norc "$@"
      '';
    };

  cached-nix-shell = nixpkgs.writeShellApplication {
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
          nixpkgs.cached-nix-shell.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./fix-trace.patch ];
          })
        )
      } "$@"
    '';
  };

  # TODO: I shouldn't have to do this. Either nixpkgs should add the completion
  # files, as they do with lefthook[1], or the tool itself should generate the files
  # as part of its build script, as direnv does[2].
  #
  # [1]: https://github.com/NixOS/nixpkgs/blob/cd7ab3a2bc59a881859a901ba1fa5e7ddf002e5e/pkgs/by-name/le/lefthook/package.nix
  # [2]: https://github.com/direnv/direnv/blob/29df55713c253e3da14b733da283f03485285cea/GNUmakefile
  zoxide =
    let
      oldZoxide = nixpkgs.zoxide;

      fishConfig =
        (nixpkgs.runCommand "zoxide-fish-config-${oldZoxide.version}" { } ''
          config_directory="$out/share/fish/vendor_conf.d"
          mkdir -p "$config_directory"
          ${getExe oldZoxide} init --no-cmd fish > "$config_directory/zoxide.fish"
        '')
        // {
          inherit (oldZoxide) version;
        };

      newZoxide = nixpkgs.symlinkJoin {
        inherit (oldZoxide) pname version;
        paths = [
          oldZoxide
          fishConfig
        ];
      };
    in
    # Merge with the original package to retain attributes like meta
    recursiveUpdate oldZoxide newZoxide;

  # TODO: I shouldn't have to do this. Either nixpkgs should add the completion
  # files, as they do with lefthook[1], or the tool itself should generate the files
  # as part of its build script, as direnv does[2].
  #
  # [1]: https://github.com/NixOS/nixpkgs/blob/cd7ab3a2bc59a881859a901ba1fa5e7ddf002e5e/pkgs/by-name/le/lefthook/package.nix
  # [2]: https://github.com/direnv/direnv/blob/29df55713c253e3da14b733da283f03485285cea/GNUmakefile
  broot =
    let
      oldBroot = nixpkgs.broot;

      fishConfig =
        (nixpkgs.runCommand "broot-fish-config-${oldBroot.version}" { } ''
          config_directory="$out/share/fish/vendor_conf.d"
          mkdir -p "$config_directory"
          ${getExe oldBroot} --print-shell-function fish > "$config_directory/broot.fish"
        '')
        // {
          inherit (oldBroot) version;
        };

      newBroot = nixpkgs.symlinkJoin {
        inherit (oldBroot) pname version;
        paths = [
          oldBroot
          fishConfig
        ];
      };
    in
    # Merge with the original package to retain attributes like meta
    recursiveUpdate oldBroot newBroot;
}
