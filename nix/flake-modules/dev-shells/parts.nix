# This function returns a map of dev shells that each represent a part of a full dev
# shell. I do this for these reasons:
#   - Allows parts of a dev shell to be shared between two shells. For example, I can
#     create one part with all the dependencies for checks (linters, formatters, etc.)
#     and include that part in both the local development and CI dev shells. This
#     way they can stay in sync.
#   - Makes it easier to organize the dev shell since it can be broken down into
#     smaller groups.
#   - Makes it easier to provide alternate dev shells without certain parts. For
#     example, people that don't use VS Code may not want the part that provides
#     dependencies for it.
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
    optionalAttrs
    unique
    concatLists
    splitString
    ;
  inherit (pkgs)
    mkShellWrapperNoCC
    ;
  inherit (pkgs.stdenv) isLinux;

  lua = mkShellWrapperNoCC {
    packages = with pkgs; [ lua-language-server ];
    shellHook = ''
      prefix="$DIRENV_LAYOUT_DIR/lua-libraries"
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
rec {
  checks =
    let
      linting = mkShellWrapperNoCC {
        inputsFrom = [
          # This is needed for running lua-language-server
          lua
          # This is needed for running mypy
          speakerctl
          # This is needed for running `go mod tidy` and `gopls`
          gozip
        ];

        packages = with pkgs; [
          actionlint
          deadnix
          fish
          # for renovate-config-validator
          renovate
          shellcheck
          statix
          markdownlint-cli2
          desktop-file-utils
          golangci-lint
          gopls
          config-file-validator
          ruff
          typos
          editorconfig-checker
          nixpkgs-lint-community
          # For isutf8 and parallel. parallel isn't a linter, but it's used to run
          # any linter that doesn't support multiple file arguments.
          moreutils
        ];
      };

      formatting = mkShellWrapperNoCC {
        packages = with pkgs; [
          nixfmt-rfc-style
          nodePackages.prettier
          shfmt
          stylua
          taplo
          ruff
          # for gofmt
          go
          # for fish_indent
          fish
        ];
      };

      codeGeneration = mkShellWrapperNoCC {
        inputsFrom = [
          # This is needed for generating task documentation
          taskRunner
        ];

        packages = with pkgs; [
          doctoc
          gomod2nix
          coreutils
          markdown2html-converter
        ];
      };
    in
    mkShellWrapperNoCC {
      inputsFrom = [
        # Runs the checks
        lefthook

        linting
        formatting
        codeGeneration
      ];

      shellHook = ''
        export RUFF_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/ruff"
      '';
    };

  ciEssentials =
    let
      # The full set of locales is pretty big (~220MB) so I'll only include the ones
      # I need.
      locales = pkgs.glibcLocales.override {
        allLocales = false;
        locales = [
          "en_US.UTF-8/UTF-8"
          "C.UTF-8/UTF-8"
        ];
      };

      # Nix recommends setting this for non-NixOS Linux distributions[1] and
      # Ubuntu is used in CI.
      #
      # TODO: See if Nix should do this as part of its setup script
      #
      # [1]: https://nixos.wiki/wiki/Locales
      localeArchiveHook = ''
        export LOCALE_ARCHIVE=${locales}/lib/locale/locale-archive
      '';
    in
    mkShellWrapperNoCC (
      {
        inputsFrom = [ scriptInterpreter ];
        packages = [ pkgs.bash-script ];
      }
      // optionalAttrs isLinux {
        shellHook = localeArchiveHook;
      }
    );

  gozip = mkShellWrapperNoCC {
    packages = with pkgs; [ go ];
    shellHook = ''
      export GOPATH="''${XDG_CACHE_HOME:-$HOME/.cache}/go"
      mkdir -p "$GOPATH"

      # Binary names could conflict between projects so store them in a
      # project-specific directory.
      export GOBIN="$DIRENV_LAYOUT_DIR/go-bin"
      mkdir -p "$GOBIN"
      export PATH="''${GOBIN}''${PATH:+:$PATH}"
    '';
  };

  lefthook = mkShellWrapperNoCC {
    packages = [
      pkgs.lefthook
      # TODO: Lefthook won't run unless git is present so maybe nixpkgs should make
      # it a dependency.
      pkgs.gitMinimal
    ];
  };

  # This part contains the dependencies of all scripts. This is useful for two
  # reasons:
  #   - Having the dependencies for all scripts exposed in the environment makes
  #     debugging a bit easier since you can easily call any commands referenced in a
  #     script.
  #   - Once the dev shell has been loaded, you can work offline since all the
  #     dependencies have already been fetched.
  scriptDependencies = pipe projectRoot [
    # Get all nix-shell shebang scripts
    (fileset.fileFilter (file: file.hasExt "bash"))
    # The scripts in dotfiles/ don't use nix-shell shebangs
    (bashScripts: fileset.difference bashScripts (projectRoot + /dotfiles))
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

  scriptInterpreter =
    let
      flakePackageSetHook =
        let
          # These are the files needed by flake-package-set.nix and nixpkgs.nix
          #
          # You may be wondering why I'm using a fileset instead of just using
          # $PWD/nix/{flake-package-set,nixpkgs}.nix. cached-nix-shell traces the
          # files accessed during the nix-shell invocation so it knows when to
          # invalidate the cache. When I use $PWD, a lot more files, like
          # $PWD/.git/index, become part of the trace, resulting in much more cache
          # invalidations.
          source =
            pipe
              [
                "flake.nix"
                "flake.lock"
                "nix"
              ]
              [
                (map (relativePath: projectRoot + "/${relativePath}"))
                fileset.unions
                (
                  union:
                  fileset.toSource {
                    root = projectRoot;
                    fileset = union;
                  }
                )
              ];
        in
        ''
          function is_running_in_ci {
            # Most CI systems, e.g. GitHub Actions, set this variable to 'true'.
            [[ ''${CI:-} == 'true' ]]
          }

          # To avoid hard coding the path to the flake package set in every script's
          # nix-shell shebang, I export a variable with the path.
          export FLAKE_PACKAGE_SET_FILE=${source}/nix/flake-package-set.nix

          # I need to set the nix path because my scripts' shebangs use nix-shell
          # which looks up nixpkgs on the nix path so it can use nixpkgs.runCommand
          # to run the script. You can also set the nixpkgs used by nix-shell by
          # using the -I flag in the script shebang, but I don't do that since I
          # would have to hardcode the path to nixpkgs.nix in every script.
          #
          # I'm not setting this locally so comma still works[1]. If I did
          # set it, then comma would use this nixpkgs instead of the one for
          # my system. Even if I were ok with that, I didn't build an index
          # for this nixpkgs so comma wouldn't be able to use it anyway. The
          # consequence of this is that the user's nixpkgs will be used instead,
          # but that shouldn't be a problem unless a breaking change is made to
          # runCommand.
          #
          # [1]: https://github.com/nix-community/comma
          if is_running_in_ci; then
            export NIX_PATH="nixpkgs=${source}/nix/nixpkgs.nix''${NIX_PATH:+:$NIX_PATH}"
          fi
        '';
    in
    mkShellWrapperNoCC {
      # cached-nix-shell is used in script shebangs
      packages = with pkgs; [ cached-nix-shell ];
      shellHook = flakePackageSetHook;
    };

  speakerctl = pkgs.speakerctl.devShell;

  sync = mkShellWrapperNoCC {
    inputsFrom = [
      # Runs the syncs
      lefthook
    ];
    packages = with pkgs; [
      # These get called in the lefthook config
      runAsAdmin
    ];
  };

  taskRunner = mkShellWrapperNoCC {
    packages = with pkgs; [
      mise
      # These get used in the mise config
      fish
      yq-go
      coreutils
      bash-script
      gomod2nix
    ];
    shellHook = ''
      mise trust --quiet
    '';
  };

  # Everything needed by the VS Code extensions recommended in
  # .vscode/extensions.json
  vsCode =
    let
      efmLanguageServer = mkShellWrapperNoCC {
        packages = with pkgs; [
          efm-langserver

          # These aren't linters, but get used in some of the linting commands.
          bash
          jq
        ];
      };
    in
    mkShellWrapperNoCC {
      inputsFrom = [
        # For "llllvvuu.llllvvuu-glspc"
        efmLanguageServer
        # For "sumneko.lua"
        lua
      ];
      packages = with pkgs; [
        # For "golang.go"
        go
        golangci-lint
        # For "tamasfe.even-better-toml"
        taplo
        # For "jnoortheen.nix-ide"
        nixd
        # For "mads-hartmann.bash-ide-vscode"
        shellcheck
        # For "charliermarsh.ruff"
        ruff
        # For "bmalehorn.vscode-fish"
        fish
        # For "rogalmic.bash-debug". It needs bash, cat, mkfifo, rm, and pkill
        bashInteractive
        coreutils
        partialPackages.pkill
      ];
      # For "ms-python.python". Link python to a stable location so I don't
      # have to update "python.defaultInterpreterPath" in settings.json when the nix
      # store path for python changes.
      shellHook = ''
        # python is in <python_directory>/bin/python so 2 dirnames will get me the
        # python directory
        python_directory="$(dirname "$(dirname "$(which python)")")"
        ln --force --no-dereference --symbolic \
          "$python_directory" "$DIRENV_LAYOUT_DIR/python"
      '';
    };
}
