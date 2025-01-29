# The function returns a map of dev shells that I call "partials" since they
# represent parts of a full dev shell. Partials can be included in a full dev shell
# using the `inputsFrom` argument for `mkShell`. They're similar to devcontainer
# "features"[1], except these are specific to a project. I use partials for these
# reasons:
#   - Allows parts of a dev shell to be shared between two shells. For example, I can
#     put all the dependencies for checks (linters, formatters, etc.) in a partial
#     and include that partial in both the local development and CI dev shells. This
#     way they can stay in sync.
#   - Makes it easier to organize the dev shell since it can be broken down into
#     smaller groups.
#   - Makes it easier to provide alternate dev shells without certain partials. For
#     example, people that don't use VS Code may not want the partial that provides
#     dependencies for it.
#
# [1]: https://containers.dev/implementors/features/

{
  utils,
  lib,
  pkgs,
  ...
}:
let
  inherit (utils) projectRoot removeRecurseIntoAttrs;
  inherit (lib)
    pipe
    fileset
    optionalAttrs
    ;
  inherit (pkgs)
    mkShellWrapperNoCC
    linkFarm
    ;
  inherit (pkgs.stdenv) isLinux;

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

  # This should be included in every dev shell that's used in CI.
  ciEssentials =
    let
      # Nix recommends setting this for non-NixOS Linux distributions[1] and
      # Ubuntu is used in CI.
      #
      # TODO: See if Nix should do this as part of its setup script
      #
      # [1]: https://nixos.wiki/wiki/Locales
      localeArchiveHook = ''
        export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
      '';
    in
    mkShellWrapperNoCC (
      {
        inputsFrom = [ scriptInterpreter ];
        packages = [ pkgs.ci-bash ];
      }
      // optionalAttrs isLinux {
        shellHook = localeArchiveHook;
      }
    );

  speakerctl = pkgs.speakerctl.devShell;

  gozip = mkShellWrapperNoCC {
    packages = with pkgs; [ go ];
    shellHook = ''
      gopath="$DIRENV_LAYOUT_DIR/go"
      mkdir -p "$gopath"
      export GOPATH="''${gopath}''${GOPATH:+:$GOPATH}"

      export GOBIN="''${GOPATH}/bin"
      mkdir -p "$GOBIN"
      export PATH="''${GOBIN}''${PATH:+:$PATH}"
    '';
  };

  taskRunner = mkShellWrapperNoCC {
    packages = with pkgs; [
      mise
      # This is needed for the autocompletion of task arguments
      usage
      # These get used in the mise config
      lefthook
      fish
    ];
    shellHook = ''
      mise trust --quiet
    '';
  };

  gitHooks = mkShellWrapperNoCC {
    packages = with pkgs; [ lefthook ];
  };

  sync = mkShellWrapperNoCC {
    packages = with pkgs; [
      # These get called in the lefthook config
      gitMinimal
      runAsAdmin

      # Runs the sync tasks
      lefthook
    ];
  };

  checks =
    let
      linting = mkShellWrapperNoCC {
        inputsFrom = [
          # For mypy. Also for the python libraries used by speakerctl so mypy can
          # factor in their types as well.
          speakerctl
        ];

        packages = with pkgs; [
          actionlint
          deadnix
          fish
          # for renovate-config-validator
          renovate
          shellcheck
          statix
          # for ltex-cli-plus
          ltex-ls-plus
          markdownlint-cli2
          desktop-file-utils
          golangci-lint
          config-file-validator
          ruff
          # for 'go mod tidy'
          go
          typos
          editorconfig-checker
          nixpkgs-lint-community
          hjson-go
          # For isutf8 and parallel. parallel isn't a linter, but it's used to run
          # any linter that doesn't support multiple file arguments.
          moreutils

          # These aren't linters, but they also get called in lefthook as part of
          # certain linting commands.
          gitMinimal
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
        linting
        formatting
        codeGeneration
      ];

      # Runs the checks
      packages = with pkgs; [ lefthook ];

      shellHook = ''
        export RUFF_CACHE_DIR="$DIRENV_LAYOUT_DIR/ruff-cache"
      '';
    };

  # Everything needed by the VS Code extensions recommended in
  # .vscode/extensions.json
  vsCode =
    let
      efmLs = mkShellWrapperNoCC {
        # Include checks since it has the linters
        inputsFrom = [ checks ];
        packages = with pkgs; [
          efm-langserver

          # These aren't linters, but get used in some of the linting commands.
          dash
          bash
          jq
        ];
      };

      luaLs =
        let
          # The set passed to linkFarm can only contain derivations
          myVimPlugins = linkFarm "plugins" (removeRecurseIntoAttrs pkgs.myVimPlugins);
        in
        mkShellWrapperNoCC {
          packages = with pkgs; [ lua-language-server ];
          shellHook = ''
            prefix="$DIRENV_LAYOUT_DIR/lua-libraries"
            mkdir -p "$prefix"

            ln --force --no-dereference --symbolic \
              ${myVimPlugins} "$prefix/neovim-plugins"
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
        # For "llllvvuu.llllvvuu-glspc"
        efmLs
        # For "sumneko.lua"
        luaLs
        # For "ms-python.mypy-type-checker", it needs mypy. Also for the python
        # libraries used by speakerctl so mypy can factor in their types as well.
        speakerctl
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
      # For extension "ms-python.python". Link python to a stable location so I don't
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
in
{
  inherit
    scriptInterpreter
    ciEssentials
    speakerctl
    gozip
    taskRunner
    gitHooks
    sync
    checks
    vsCode
    ;
}
