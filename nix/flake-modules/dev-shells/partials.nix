{
  utils,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) readFile;
  inherit (utils) projectRoot removeRecurseIntoAttrs;
  inherit (lib)
    pipe
    init
    splitString
    ;
  inherit (pkgs)
    mkShellUniqueNoCC
    linkFarm
    runCommand
    ;

  plugctlPython = import ../../plugctl-python.nix pkgs;

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

  versionControl = mkShellUniqueNoCC {
    packages = with pkgs; [
      gitMinimal
      lefthook
    ];
  };

  languages = mkShellUniqueNoCC {
    packages = with pkgs; [
      bashInteractive
      go
    ];
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

  scriptDependencies =
    let
      dependencyFile =
        runCommand "script-dependencies"
          {
            nativeBuildInputs = with pkgs; [
              ripgrep
            ];
          }
          ''
            # Extract script dependencies from their nix-shell shebangs.
            #
            # The shebang looks something like:
            #   #! nix-shell --packages "with ...; [dep1 dep2 dep3]"
            #
            # So this command will extract everything between the brackets i.e.
            #   'dep1 dep2 dep3'.
            #
            # Each line printed will contain the extraction above, per script.
            rg \
              --no-filename \
              --glob '*.bash' \
              '^#! nix-shell (--packages|-p) .*\[(?P<packages>.*)\].*' \
              --replace '$packages' \
              ${projectRoot + /scripts} |

            # Flatten the output of the previous command i.e. print _one_
            # dependency per line
            rg --only-matching '[^\s]+' |

            sort --unique > $out
          '';
    in
    pipe dependencyFile [
      readFile
      (splitString "\n")
      # The file ends in a newline so the last line will be empty
      init
      (map (dependencyName: pkgs.${dependencyName}))
      (dependencies: mkShellUniqueNoCC { packages = dependencies; })
    ];
in
{
  inherit
    plugctl
    linting
    formatting
    codeGeneration
    vsCode
    taskRunner
    versionControl
    languages
    sync
    scriptDependencies
    ;
}
