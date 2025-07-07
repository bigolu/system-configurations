# This function returns a map of dev shells that each represent a piece of a full dev
# shell. This has the following advantages:
#   - Fragments can be shared between full dev shells. For example, you can
#     create one fragment with all the dependencies for checks (linters, formatters,
#     etc.) and include that fragment in both the development and CI dev shells. This
#     way, they can stay in sync.
#   - Makes it easier to tell what each dependency is being used for since
#     dependencies belong to narrowly-scoped fragments, instead of one big dev shell.
#   - Makes it easier to provide alternate dev shells without certain fragments. For
#     example, people that don't use VS Code may not want the fragment that provides
#     dependencies for it.
{
  utils,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins)
    concatLists
    match
    elemAt
    ;
  inherit (utils) projectRoot;
  inherit (lib)
    pipe
    fileset
    optionals
    ;
  inherit (pkgs)
    mkShellNoCC
    linkFarm
    extractNixShebangPackages
    mkGoEnv
    ;
  inherit (pkgs.stdenv) isLinux;
in
rec {
  lefthook = mkShellNoCC {
    packages = [
      pkgs.lefthook
      # TODO: Lefthook won't run unless git is present so maybe nixpkgs should make
      # it a dependency.
      pkgs.git
    ];
  };

  shellHookHelpers = mkShellNoCC {
    shellHook = ''
      # We could just always recreate the symlink, even if the target of the symlink
      # is the same, but since we use direnv, this would happen every time we load
      # the environment. This causes the following the problems:
      #   - It's slower so there would be a little lag when you enter the directory.
      #   - Some of these symlinks are being watched by programs and recreating them
      #     causes those programs to reload. For example, VS Code watches the symlink
      #     to Python.
      function symlink_if_target_changed {
        local -r target="$1"
        local -r symlink_path="$2"

        if [[ ! $target -ef $symlink_path ]]; then
          ln --force --no-dereference --symbolic "$target" "$symlink_path"
        fi
      }

      # perf: We could just always run `mkdir -p`, but since we use direnv, this
      # would happen every time we load the environment and it's slower than checking
      # if the directory exists.
      function mkdir_if_missing {
        local -r dir="$1"

        if [[ ! -d $dir ]]; then
          mkdir -p "$dir"
        fi
      }
    '';
  };

  ciEssentials =
    let
      # Nix recommends setting the LOCALE_ARCHIVE environment variable for non-NixOS
      # Linux distributions[1] and Ubuntu is used in CI. Though, we don't need to
      # explicitly set LOCALE_ARCHIVE since `glibcLocales` has a setup-hook that will
      # do it.
      #
      # TODO: See if Nix should do this as part of its setup script
      #
      # [1]: https://nixos.wiki/wiki/Locales
      locale = mkShellNoCC {
        packages = [
          # The full set of locales is pretty big (~220MB) so I'll only include the
          # one that will be used.
          (pkgs.glibcLocales.override {
            allLocales = false;
            locales = [ "en_US.UTF-8/UTF-8" ];
          })
        ];
        shellHook = ''
          # This tells programs to use the locale we provided above
          export LC_ALL='en_US.UTF-8'
        '';
      };
    in
    mkShellNoCC {
      inputsFrom = [ taskRunner ] ++ optionals isLinux [ locale ];
      # For the `run` steps in CI workflows
      packages = [ pkgs.bash-script ];
    };

  direnv = mkShellNoCC {
    packages = [ pkgs.nvd ];
  };

  gozip =
    let
      setGoBin = ''
        # Binary names could conflict between projects so store them in a
        # project-specific directory.
        export GOBIN="''${direnv_layout_dir:-$PWD/.direnv}/go-bin"
        export PATH="''${GOBIN}''${PATH:+:$PATH}"
      '';

      goEnv = mkGoEnv { pwd = ../../../../gozip; };

      # TODO: Maybe this could be upstreamed to gomod2nix
      linkVendoredModules = pipe goEnv.buildPhase [
        # TODO: Instead of having to do this, gomod2nix should expose the mkVendorEnv
        # function in their public API.
        #
        # WARNING: `builtins.match` is inconsistent across platforms[1].
        #
        # [1]: https://github.com/NixOS/nix/issues/1537
        (match ".* (/nix/store/[0123456789abcdfghijklmnpqrsvwxyz]{32}-vendor-env).*")
        (matches: elemAt matches 0)

        (vendor: ''
          # Most CI systems, e.g. GitHub Actions, set CI to 'true'.
          #
          # I only use this in CI because it would it would be too inconvenient to
          # use during development: Go either reads all dependencies from GOPATH or
          # the vendor directory so a change to go.mod would require regenerating the
          # gomod2nix lock and reloading the dev shell. There's an open issue for
          # partial vendoring[1]. If this is done, then I could start using this for
          # development. It's especially important that this is used in CI because in
          # CI, checks (e.g. `gopls check`) are run without internet access so Go
          # wouldn't be able to download modules. Another alternative would be using
          # GOCACHEPROG with gobuild.nix[2].
          #
          # [1]: https://github.com/golang/go/issues/52604
          # [2]: https://github.com/katexochen/gobuild.nix
          if [[ ''${CI:-} == 'true' ]]; then
            export GOFLAGS='-mod=vendor'
            export GO_NO_VENDOR_CHECKS='1'
            symlink_if_target_changed ${vendor} gozip/vendor
          fi
        '')
      ];
    in
    mkShellNoCC {
      packages = [ goEnv ];
      shellHook = setGoBin + linkVendoredModules;
    };

  speakerctl = pkgs.speakerctl.devShell;

  check =
    let
      lua-language-server = mkShellNoCC {
        packages = [ pkgs.lua-language-server ];
        shellHook = ''
          prefix="''${direnv_layout_dir:-.direnv}/lua-libraries"
          mkdir_if_missing "$prefix"

          symlink_if_target_changed \
            ${pkgs.myVimPluginPack}/pack/bigolu/start "$prefix/neovim-plugins"
          symlink_if_target_changed \
            ${pkgs.neovim}/share/nvim/runtime "$prefix/neovim-runtime"

          hammerspoon_annotations="$HOME/.hammerspoon/Spoons/EmmyLua.spoon/annotations"
          if [[ -e $hammerspoon_annotations ]]; then
            symlink_if_target_changed \
              "$hammerspoon_annotations" "$prefix/hammerspoon-annotations"
          fi
        '';
      };
    in
    mkShellNoCC {
      inputsFrom = [
        # Runs the checks
        lefthook
        # This is needed for generating task documentation
        taskRunner
        # For `gofmt`, `go mod tidy`, `gopls`, and `golangci-lint`
        gozip
        # This is needed for running mypy
        speakerctl
        lua-language-server
      ];
      packages = with pkgs; [
        actionlint
        config-file-validator
        deadnix
        doctoc
        editorconfig-checker
        # For `fish_indent` and `fish`
        fish
        golangci-lint
        gomod2nix
        gopls
        markdown2html-converter
        markdownlint-cli2
        # TODO: I use `chronic` to hide the output of commands that produce a lot of
        # output even when they exit successfully. I should see if I could change
        # this upstream.
        #
        # I also use this for `isutf8` and `parallel`. `parallel` is used to run any
        # check that doesn't support multiple file arguments.
        moreutils
        nixfmt-rfc-style
        nixpkgs-lint-community
        nodePackages.prettier
        perl
        # for renovate-config-validator
        renovate
        ruff
        shellcheck
        shfmt
        statix
        stylua
        taplo
        typos
      ];
    };

  sync = mkShellNoCC {
    # Runs the sync jobs
    inputsFrom = [ lefthook ];
    packages = with pkgs; [
      # These get called in the lefthook config
      chase
      nix-output-monitor
    ];
  };

  taskRunner = mkShellNoCC {
    packages = with pkgs; [
      mise
      cached-nix-shell
    ];
    shellHook = ''
      # perf: We could just always run `mise trust --quiet`, but since we use direnv,
      # this would happen every time we load the environment and it's slower than
      # checking if a file exists.
      trust_marker="''${direnv_layout_dir:-.direnv}/mise-config-trusted"
      if [[ ! -e $trust_marker ]]; then
        mise trust --quiet
        touch "$trust_marker"
      fi

      # I don't want to make GC roots when debugging CI because unlike actual CI,
      # where new virtual machines are created for each run, they'll just accumulate.
      #
      # Most CI systems, e.g. GitHub Actions, set CI to 'true'.
      if [[ ''${CI:-} == 'true' ]] && [[ ''${CI_DEBUG:-} != 'true' ]]; then
        export NIX_SHEBANG_GC_ROOTS_DIR="''${direnv_layout_dir:-$PWD/.direnv}/nix-shebang-dependencies"
      fi
    '';
  };

  # These are the dependencies of the commands run within `complete` statements in
  # mise tasks. I could use nix shebang scripts instead, but then autocomplete
  # would be delayed by the time it takes to load a nix shell.
  taskAutocomplete = mkShellNoCC {
    packages = with pkgs; [
      fish
      # For nix's fish shell autocomplete
      (linkFarm "nix-share" { share = "${pkgs.nix}/share"; })
    ];
  };

  # This fragment contains the dependencies of all tasks. Though nix-shell will fetch
  # the dependencies for a script when it's executed, it's useful to load them ahead
  # of time for these reasons:
  #   - Having the dependencies for all tasks exposed in the environment makes
  #     debugging a bit easier since you can easily call any commands referenced in a
  #     task.
  #   - Once the dev shell has been loaded, you can work offline since all the
  #     dependencies have already been fetched.
  #   - Since the dev shell is a garbage collection root, these task dependencies
  #     won't get garbage collected.
  tasks = pipe (projectRoot + /mise/tasks) [
    (fileset.fileFilter (file: file.hasExt "bash"))
    fileset.toList
    (map extractNixShebangPackages)
    concatLists
    # Nix shebangs also depend on stdenv
    (packages: packages ++ [ pkgs.stdenv ])
    # Scripts use `nix-shell-interpreter` as their interpreter to work around an
    # issue with nix-shell, but bashInteractive can be used locally for
    # debugging. It's important that bashInteractive is added to the front of the
    # list because otherwise non-interactive bash will shadow it on the PATH.
    (dependencies: [ pkgs.bashInteractive ] ++ dependencies)
    (dependencies: mkShellNoCC { packages = dependencies; })
  ];

  # Everything needed by the VS Code extensions recommended in
  # .vscode/extensions.json
  vsCode =
    let
      efmLanguageServer = mkShellNoCC {
        packages = with pkgs; [
          efm-langserver
          # These get used in some of the commands in the efm-langserver config.
          bash
          jq
        ];
      };
    in
    mkShellNoCC {
      inputsFrom = [
        # For "llllvvuu.llllvvuu-glspc"
        efmLanguageServer
      ];
      packages = with pkgs; [
        # For "jnoortheen.nix-ide"
        nixd
        # These are for "rogalmic.bash-debug". It needs bash, cat, mkfifo, rm, and
        # pkill
        bashInteractive
        coreutils
        partialPackages.pkill
      ];
      # For "ms-python.python". Link python to a stable location so I don't
      # have to update "python.defaultInterpreterPath" in settings.json when the nix
      # store path for python changes.
      shellHook = ''
        symlink_if_target_changed \
          ${pkgs.speakerctl.python} "''${direnv_layout_dir:-.direnv}/python"
      '';
    };
}
