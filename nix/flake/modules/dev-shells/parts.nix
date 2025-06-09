# This function returns a map of dev shells that each represent a part of a full dev
# shell, similar to Dev Container Features[1]. I do this for these reasons:
#   - Allows parts of a dev shell to be shared between two shells. For example, I can
#     create one part with all the dependencies for checks (linters, formatters,
#     etc.) and include that part in both the development and CI dev shells. This way
#     they can stay in sync.
#   - Makes it easier to organize the dev shell since it can be broken down into
#     smaller groups.
#   - Makes it easier to provide alternate dev shells without certain parts. For
#     example, people that don't use VS Code may not want the part that provides
#     dependencies for it.
#
# [1]: https://github.com/devcontainers/features
{
  utils,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins)
    readFile
    match
    filter
    elemAt
    ;
  inherit (utils) projectRoot;
  inherit (lib)
    pipe
    fileset
    optionals
    unique
    concatLists
    splitString
    removeSuffix
    ;
  inherit (pkgs)
    mkShellWrapperNoCC
    linkFarm
    writeText
    ;
  inherit (pkgs.stdenv) isLinux;
in
rec {
  lefthook = mkShellWrapperNoCC {
    packages = [
      pkgs.lefthook
      # TODO: Lefthook won't run unless git is present so maybe nixpkgs should make
      # it a dependency.
      pkgs.git
    ];
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
      locale = mkShellWrapperNoCC {
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
    mkShellWrapperNoCC {
      inputsFrom =
        [
          taskRunner
        ]
        ++ optionals isLinux [
          locale
        ];
      packages = [
        # For the `run` steps in CI workflows
        pkgs.bash-script
      ];
    };

  gozip =
    let
      setGoBin = ''
        # Binary names could conflict between projects so store them in a
        # project-specific directory.
        export GOBIN="''${direnv_layout_dir:-$PWD/.direnv}/go-bin"
        mkdir -p "$GOBIN"
        export PATH="''${GOBIN}''${PATH:+:$PATH}"
      '';

      goEnv = pkgs.mkGoEnv { pwd = ../../../../gozip; };

      # TODO: Maybe this could be upstreamed to gomod2nix
      linkVendoredModules = pipe goEnv.buildPhase [
        # TODO: `builtins.match` is inconsistent across platforms[1] so I'll use grep
        # instead.
        #
        # [1]: https://github.com/NixOS/nix/issues/1537
        (
          phase:
          pkgs.runCommand "vendor" { } ''
            grep -o '/nix/store/[^/]*vendor-env' <${writeText "phase" phase} >$out
          ''
        )
        readFile
        (removeSuffix "\n")

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
            ln --force --no-dereference --symbolic ${vendor} gozip/vendor
          fi
        '')
      ];
    in
    mkShellWrapperNoCC {
      packages = [ goEnv ];
      shellHook = setGoBin + linkVendoredModules;
    };

  speakerctl = pkgs.speakerctl.devShell;

  commitMsgHook = mkShellWrapperNoCC {
    # These are used in the lefthook config for the commit-msg and
    # check-commit-message hooks.
    packages = with pkgs; [
      gnused
      typos
      # For `mktemp`
      coreutils
    ];
  };

  check =
    let
      lua-language-server = mkShellWrapperNoCC {
        packages = [ pkgs.lua-language-server ];
        shellHook = ''
          prefix="''${direnv_layout_dir:-.direnv}/lua-libraries"
          mkdir -p "$prefix"

          ln --force --no-dereference --symbolic \
            ${pkgs.myVimPluginPack}/pack/bigolu/start "$prefix/neovim-plugins"
          ln --force --no-dereference --symbolic \
            ${pkgs.neovim}/share/nvim/runtime "$prefix/neovim-runtime"

          hammerspoon_annotations="$HOME/.hammerspoon/Spoons/EmmyLua.spoon/annotations"
          if [[ -e $hammerspoon_annotations ]]; then
            ln --force --no-dereference --symbolic \
              "$hammerspoon_annotations" "$prefix/hammerspoon-annotations"
          fi
        '';
      };
    in
    mkShellWrapperNoCC {
      inputsFrom = [
        # Runs the checks
        lefthook
        # This is needed for generating task documentation
        taskRunner
        # For `gofmt`, `go mod tidy`, and `gopls`
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

  sync = mkShellWrapperNoCC {
    inputsFrom = [
      # Runs the sync jobs
      lefthook
    ];
    packages = with pkgs; [
      # These get called in the lefthook config
      chase
      markdown2html-converter
    ];
  };

  taskRunner =
    let
      fileTaskRunner = mkShellWrapperNoCC {
        packages = with pkgs; [ cached-nix-shell ];
        shellHook = ''
          # I don't want to make GC roots when debugging CI because unlike actual CI,
          # where new virtual machines are created for each run, they'll just
          # accumulate.
          #
          # Most CI systems, e.g. GitHub Actions, set CI to 'true'.
          if [[ ''${CI:-} == 'true' ]] && [[ ''${CI_DEBUG:-} != 'true' ]]; then
            export NIX_SHEBANG_GC_ROOTS_DIR="''${PWD}/.direnv/nix-shebang-dependencies"
          fi
        '';
      };

      inlineTaskRunner = mkShellWrapperNoCC {
        packages = with pkgs; [ bash-script ];
      };
    in
    mkShellWrapperNoCC {
      inputsFrom = [
        fileTaskRunner
        inlineTaskRunner
      ];
      packages = with pkgs; [ mise ];
      shellHook = "mise trust --quiet";
    };

  # These are the dependencies of the commands run within `complete` statements in
  # mise tasks. I could use nix shell shebang scripts instead, but then autocomplete
  # would be delayed by the time it takes to load a nix shell.
  taskAutocomplete = mkShellWrapperNoCC {
    packages = with pkgs; [
      fish
      # For nix's fish shell autocomplete
      (linkFarm "nix-share" { share = "${pkgs.nix}/share"; })
    ];
  };

  # This part contains the dependencies of all tasks. Though nix-shell will fetch the
  # dependencies for a script when it's executed, it's useful to load them ahead of
  # time for these reasons:
  #   - Having the dependencies for all tasks exposed in the environment makes
  #     debugging a bit easier since you can easily call any commands referenced in a
  #     task.
  #   - Once the dev shell has been loaded, you can work offline since all the
  #     dependencies have already been fetched.
  #   - Since the dev shell is a garbage collection root, these task dependencies
  #     won't get garbage collected.
  tasks = pipe (projectRoot + /mise/tasks) [
    # Get all nix-shell shebang scripts
    (fileset.fileFilter (file: file.hasExt "bash"))
    (
      nixShellShebangScripts:
      fileset.toSource {
        root = projectRoot;
        fileset = nixShellShebangScripts;
      }
    )

    # Get all lines in all scripts
    lib.filesystem.listFilesRecursive
    (map readFile)
    (map (splitString "\n"))
    concatLists

    # Extract script dependencies from their nix-shell shebangs.
    #
    # The shebang looks something like:
    #   #! nix-shell --packages "with ...; [dep1 dep2 dep3]"
    #
    # So this match will extract everything between the brackets i.e.
    #   'dep1 dep2 dep3'.
    (map (match ''^#! nix-shell (--packages|-p) .*\[(.*)].*''))
    (filter (matches: matches != null))
    (map (matches: elemAt matches 1))

    # Flatten the output of the previous match i.e. each string in the list will
    # hold _one_ dependency, instead of multiple separated by a space.
    (map (splitString " "))
    concatLists

    unique
    (map (dependencyName: pkgs.${dependencyName}))
    # Scripts use `nix-shell-interpreter` as their interpreter to work around an
    # issue with nix-shell, but bashInteractive can be used locally for
    # debugging. It's important that bashInteractive is added to the front of the
    # list because otherwise non-interactive bash will shadow it on the PATH.
    (dependencies: [ pkgs.bashInteractive ] ++ dependencies)
    (dependencies: mkShellWrapperNoCC { packages = dependencies; })
  ];

  # Everything needed by the VS Code extensions recommended in
  # .vscode/extensions.json
  vsCode =
    let
      efmLanguageServer = mkShellWrapperNoCC {
        packages = with pkgs; [
          efm-langserver
          # These get used in some of the commands in the efm-langserver config.
          bash
          jq
        ];
      };
    in
    mkShellWrapperNoCC {
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
        # python is in <python_directory>/bin/python so moving up once from bin/ will
        # get me to the python directory
        python_directory="$(dirname "$(which python)")/.."
        ln --force --no-dereference --symbolic \
          "$python_directory" "''${direnv_layout_dir:-.direnv}/python"
      '';
    };
}
