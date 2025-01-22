# The function returns a map of dev shells that I call "partials" since they
# represent parts of a full dev shell. Partials can be included in a full dev shell
# using the `inputsFrom` argument for `mkShell`. I use partials for these reasons:
#   - Allows parts of a dev shell to be shared between two shells. For example, I can
#     put all the dependencies for checks (linters, formatters, etc.) in a partial
#     and include that partial in both the local development and CI dev shells. This
#     way they can stay in sync.
#   - Makes it easier to organize the dev shell since it can be broken down into
#     smaller groups.
#   - Makes it easier to provide alternate dev shells without certain partials. For
#     example, people that don't use VS Code may not want the partial that provides
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
  inherit (utils) projectRoot removeRecurseIntoAttrs;
  inherit (lib)
    pipe
    splitString
    fileset
    optionalAttrs
    unique
    concatLists
    ;
  inherit (pkgs)
    mkShellUniqueNoCC
    linkFarm
    runCommand
    ;
  inherit (pkgs.stdenv) isLinux;

  plugctlPython = import ../../plugctl-python.nix pkgs;

  # This should be included in every dev shell.
  essentials =
    let
      flakePackageSetHook =
        let
          filesReferencedByFlakePackageSetFile =
            pipe
              [
                "flake.nix"
                "flake.lock"
                "default.nix"
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
          # To avoid hard coding the path to the flake package set in every
          # script with a nix-shell shebang, I export a variable with the path.
          #
          # You may be wondering why I'm using a fileset instead of just using
          # $PWD/nix/flake-package-set.nix. cached-nix-shell traces the files
          # accessed during the nix-shell invocation so it knows when to
          # invalidate the cache. When I use $PWD, a lot more files, like
          # $PWD/.git/index, become part of the trace, resulting in much more
          # cache invalidations.
          export FLAKE_PACKAGE_SET_FILE=${filesReferencedByFlakePackageSetFile}/nix/flake-package-set.nix
        '';
    in
    mkShellUniqueNoCC {
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
    mkShellUniqueNoCC (
      {
        inputsFrom = [ essentials ];
        packages = [ pkgs.ci-bash ];
      }
      // optionalAttrs isLinux {
        shellHook = localeArchiveHook;
      }
    );

  plugctl = mkShellUniqueNoCC {
    packages = [
      plugctlPython
    ];
    shellHook = ''
      # Regular python, i.e. the one without plugctl's packages, is also put on
      # the PATH so I need to make sure the one for plugctl comes first.
      PATH="${plugctlPython}/bin:$PATH"
    '';
  };

  gozip = mkShellUniqueNoCC {
    packages = with pkgs; [ go ];
  };

  linting = mkShellUniqueNoCC {
    inputsFrom = [
      # For mypy. Also for the python libraries used by plugctl so mypy can
      # factor in their types as well.
      plugctl
    ];

    packages = with pkgs; [
      # These get called in the lefthook config
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
      taplo
      ruff
      # for 'go mod tidy'
      go
      typos
      # TODO: If the YAML language server gets a CLI I should use that instead:
      # https://github.com/redhat-developer/yaml-language-server/issues/535
      yamllint
      editorconfig-checker
      nixpkgs-lint-community
      hjson-go
      # For isutf8 and parallel. parallel isn't a linter, but it's used to run
      # any linter that doesn't support multiple file arguments.
      moreutils

      # These aren't linters, but they also get called in lefthook as part of
      # certain linting commands.
      gitMinimal

      # Runs the linters
      lefthook
    ];

    shellHook =
      let
        direnvStdlib = runCommand "direnv-stdlib.bash" {
          nativeBuildInputs = [ pkgs.direnv ];
        } "direnv stdlib > $out";
      in
      ''
        direnv_directory='.direnv'
        mkdir -p "$direnv_directory"
        ln --force --no-dereference --symbolic \
          ${direnvStdlib} "$direnv_directory/stdlib.bash"
      '';
  };

  formatting = mkShellUniqueNoCC {
    packages = with pkgs; [
      # These get called in the lefthook config
      nixfmt-rfc-style
      nodePackages.prettier
      shfmt
      stylua
      just
      taplo
      ruff
      go # for gofmt
      fish # for fish_indent

      # Runs the formatters
      lefthook
    ];
  };

  codeGeneration = mkShellUniqueNoCC {
    packages = with pkgs; [
      # These get called in the lefthook config
      doctoc
      gomod2nix

      # Runs the generators
      lefthook
    ];
  };

  # Everything needed by the VS Code extensions recommended in .vscode/extensions.json
  vsCode =
    let
      # The set passed to linkFarm can only contain derivations
      plugins = linkFarm "plugins" (removeRecurseIntoAttrs pkgs.myVimPlugins);

      efmLs = mkShellUniqueNoCC {
        inputsFrom = [ linting ];
        packages = with pkgs; [
          efm-langserver
          # I use this to transform the output of some linters into something efm
          # can more easily parse.
          jq
        ];
      };
    in
    mkShellUniqueNoCC {
      inputsFrom = [
        efmLs
      ];
      packages = with pkgs; [
        go
        taplo
        nixd
      ];
      shellHook = ''
        # Link python to a stable location so I don't have to update the python
        # path in VS Code when the nix store path for python changes.
        direnv_directory='.direnv'
        mkdir -p "$direnv_directory"
        ln --force --no-dereference --symbolic \
          ${plugctlPython} "$direnv_directory/python"

        # For lua-ls
        prefix='lua-libraries'
        mkdir -p "$prefix"
        ln --force --no-dereference --symbolic \
          ${plugins} "$prefix/neovim-plugins"
        ln --force --no-dereference --symbolic \
          ${pkgs.neovim}/share/nvim/runtime "$prefix/neovim-runtime"
      '';
    };

  taskRunner = mkShellUniqueNoCC {
    packages = with pkgs; [
      just
      # This gets called in the justfile
      coreutils
    ];
  };

  gitHooks = mkShellUniqueNoCC {
    packages = with pkgs; [ lefthook ];
  };

  sync = mkShellUniqueNoCC {
    packages = with pkgs; [
      # These get called in the lefthook config
      gitMinimal
      runAsAdmin

      # Runs the sync tasks
      lefthook
    ];
  };

  # Having the dependencies for all scripts exposed in the environment makes
  # debugging them a bit easier. Ideally, there would be a way to temporarily expose
  # the dependencies of a script. nix-script can do this[1], but I don't use it for
  # these reasons:
  #   - It rebuilds the script's dependencies every time the script file changes
  #   - I couldn't find a way to control the package set that dependencies are pulled
  #     from. It seems to always use the nixpkgs entry in NIX_PATH.
  #
  # [1]: https://github.com/dschrempf/nix-script?tab=readme-ov-file#shell-mode
  scripts = pipe (projectRoot + /scripts) [
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

    # Flatten the output of the previous match i.e. print _one_
    # dependency per line
    (map (splitString " "))
    concatLists

    unique
    (map (dependencyName: pkgs.${dependencyName}))
    (dependencies: mkShellUniqueNoCC { packages = dependencies; })
  ];
in
{
  inherit
    essentials
    ciEssentials
    plugctl
    gozip
    linting
    formatting
    codeGeneration
    vsCode
    taskRunner
    gitHooks
    sync
    scripts
    ;
}
