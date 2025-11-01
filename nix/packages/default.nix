# This package set is used for non-public outputs, like home/darwin configurations or
# devShells, cached-nix-shell shebang scripts, and the command line e.g.
# `nix run --file <this_file> ...`. It's useful to put them all together so I can
# access them more easily and override packages.

let
  inherit ((import ../.. { }).context)
    inputs
    outputs
    pkgs
    lib
    nixpkgs
    utils
    pins
    system
    ;
  inherit (utils) unstableVersion projectRoot;
  inherit (lib)
    optionalAttrs
    getExe
    recursiveUpdate
    concatMap
    substring
    foldl'
    escapeShellArgs
    ;
  inherit (nixpkgs.stdenv) isLinux;

  recursiveUpdateList = foldl' recursiveUpdate { };

  filterPrograms =
    package: programsToKeep:
    let
      findFilters = concatMap (program: [
        "!"
        "-name"
        program
      ]) programsToKeep;
    in
    nixpkgs.symlinkJoin {
      name = "${package.name}-partial";
      paths = [ package ];
      nativeBuildInputs = [ nixpkgs.makeWrapper ];
      postBuild = ''
        cd $out/bin
        find . ${escapeShellArgs findFilters} -type f,l -exec rm -f {} +
      '';
    };
in
recursiveUpdateList [
  nixpkgs
  outputs.packages
  inputs.gomod2nix.outputs
  {
    # nix-shell uses `pkgs.runCommandCC` from nixpkgs to create the environment. We
    # set it to `runCommand` to make the closure smaller.
    #
    # It's not defined in the recursive set below to avoid shadowing `pkgs`
    pkgs.runCommandCC = nixpkgs.runCommand;
  }
  rec {
    __functor =
      self:
      # This file will be put on the NIX_PATH as 'nixpkgs' when we run cached-nix-shell
      # for mise tasks. This way all the packages we reference in the script will come
      # from here. Since nixpkgs is a function that returns a package set, this needs
      # to be a function as well.
      #
      # In order to have the nix CLI automatically call this function, the argument
      # must be a set with either no attributes or default values for all attributes.
      { }:
      self;

    npins = inputs.npins.outputs;

    # They only have a flake interface
    nix-sweep = inputs.nix-sweep.packages.${system}.default;

    nix-shell-interpreter = outputs.packages.nix-shell-interpreter.override {
      interpreter = bash-script;
    };

    resolveNixShellShebang = outputs.packages.resolveNixShellShebang.override { inherit pkgs; };

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
        treesj
        vim-abolish
        vim-matchup
        # For indentexpr
        vim-nix
        vim-sleuth

        # TODO: should be upstreamed to nixpkgs
        (nixpkgs.vimUtils.buildVimPlugin {
          pname = "vim-caser";
          version = pins.vim-caser.revision;
          src = pins.vim-caser;
        })
      ];
    };

    # TODO: They don't seem to be making releases anymore. I should check with the
    # author and possibly have nixpkgs track master instead.
    fishPlugins.async-prompt = nixpkgs.fishPlugins.async-prompt.overrideAttrs (_old: {
      version = pins.fish-async-prompt.revision;
      src = pins.fish-async-prompt;
    });

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
          "hostname"
          "strings"
        ];
        git-extras = filterPrograms nixpkgs.git-extras [
          "git-continue"
          "git-abort"
          "git-wip"
          "git-info"
          "git-delete-merged-branches"
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
      src = pins."config-file-validator-${system}";
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

    # Normally I'd use overrideAttrs, but that wouldn't affect
    # keyd-application-mapper.
    #
    # TODO: This derivation should instead be defined as a function that takes the
    # final derivation attributes so I can override it properly.
    keyd =
      let
        # TODO: I'm assuming that the first 10 characters is enough for it to be
        # unique.
        version = "2.5.0-${substring 0 10 pins.keyd.revision}";

        src = pins.keyd;

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

    run-as-admin = nixpkgs.writeShellApplication {
      name = "run-as-admin";
      runtimeInputs = [ nixpkgs.coreutils ];
      text = ''
        # I want to run `darwin-rebuild/home-manager switch` and only input my
        # password once, but homebrew, rightly, invalidates the sudo cache before it
        # runs[1] so I have to input my password again for subsequent steps in the
        # rebuild. This script allows ANY command to be run without a password, for
        # the duration of the specified command. It also runs the specified command
        # as the user that launched this script, i.e. SUDO_USER, and not root.
        #
        # [1]: https://github.com/Homebrew/brew/pull/17694/commits/2adf25dcaf8d8c66124c5b76b8a41ae228a7bb02

        temp="$(mktemp)"
        if [[ $OSTYPE == linux* ]]; then
          group='sudo'
        else
          group='admin'
        fi
        echo "%$group		ALL = (ALL) NOPASSWD:SETENV: ALL" >"$temp"

        sudo chown --reference /etc/sudoers "$temp"
        sudo mv "$temp" /etc/sudoers.d/temp-config
        function remove_config {
          sudo rm /etc/sudoers.d/temp-config
        }
        trap remove_config EXIT

        sudo -u "$SUDO_USER" "$@"
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
          devshellModule = {
            devshell.packages = [ pythonEnv ];
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
            inputs.nixpkgs.outputs.cached-nix-shell.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./fix-trace.patch ];
            })
          )
        } "$@"
      '';
    };

    # TODO: I shouldn't have to do this. Either nixpkgs should add the shell config
    # files or the tool itself should generate the files as part of its build script,
    # as direnv does[2].
    #
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

    # TODO: I shouldn't have to do this. Either nixpkgs should add the shell config
    # files or the tool itself should generate the files as part of its build script,
    # as direnv does[2].
    #
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
]
