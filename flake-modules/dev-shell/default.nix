{
  lib,
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      system,
      pkgs,
      inputs',
      ...
    }:
    let
      inherit (lib.attrsets) optionalAttrs;

      utilities = import ./utilities.nix { inherit pkgs self; };
      inherit (utilities) makeDevShell makeCiDevShell;

      linkLuaLsLibrariesHook =
        let
          luaLsLibraries = import ./lua-libraries.nix { inherit pkgs inputs; };
        in
        ''
          dest='.lua-ls-libraries'
          if [ -L "$dest" ]; then
            ${pkgs.coreutils}/bin/rm "$dest"
          fi
          ${pkgs.coreutils}/bin/ln --symbolic ${lib.escapeShellArg luaLsLibraries} "$dest"
        '';

      lefthookDependencies = with pkgs; [
        lefthook
        # These are called in the lefthook configuration file, but aren't
        # specific to a task group e.g. format or check-lint
        gitMinimal
        parallel
      ];

      lintingDependencies =
        with pkgs;
        [
          actionlint
          deadnix
          fish
          lychee
          renovate # for renovate-config-validator
          shellcheck
          statix
          ltex-ls # for ltex-cli
          markdownlint-cli2
          desktop-file-utils
          golangci-lint
          config-file-validator
          taplo
          ruff
          go # for 'go mod tidy'
          typos
          dos2unix

          # TODO: If the YAML language server gets a CLI I should use that instead:
          # https://github.com/redhat-developer/yaml-language-server/issues/535
          yamllint

          # This reports the errors
          reviewdog
        ]
        # Runs the linters
        ++ lefthookDependencies;

      formattingDependencies =
        with pkgs;
        [
          nixfmt-rfc-style
          fish # for fish_indent
          nodePackages.prettier
          shfmt
          stylua
          just
          go # for gofmt
          taplo
          ruff
        ]
        # Runs the formatters
        ++ lefthookDependencies;

      vsCodeDependencies =
        let
          efmDependencies = [ pkgs.efm-langserver ] ++ lintingDependencies;
        in
        with pkgs;
        [
          go
          nixd
          taplo
        ]
        ++ efmDependencies;

      taskRunnerDependencies = with pkgs; [
        just
        less # For paging the output of `just list`
      ];

      versionControlDependencies =
        with pkgs;
        [
          gitMinimal
        ]
        ++ lefthookDependencies;

      languageDependencies = with pkgs; [
        nix
        bashInteractive
        go
      ];

      codeGenerationDependencies =
        # Runs the generators
        lefthookDependencies
        # This gets called from lefthook
        ++ (with pkgs; [
          doctoc
          ripgrep
          coreutils
        ]);

      outputs = {
        # So we can cache it and pin a version.
        packages.nix-develop-gha = inputs'.nix-develop-gha.packages.default;

        legacyPackages.nixpkgs = pkgs;

        devShells = {
          default = makeDevShell {
            name = "local";
            packages =
              vsCodeDependencies
              ++ lintingDependencies
              ++ formattingDependencies
              ++ codeGenerationDependencies
              ++ taskRunnerDependencies
              ++ versionControlDependencies
              ++ languageDependencies
              ++ [ pkgs.script-dependencies ];
            shellHook =
              ''
                # For nixd
                export NIX_PATH='nixpkgs='${lib.escapeShellArg inputs.nixpkgs}
              ''
              + linkLuaLsLibrariesHook;
          };

          ci = makeCiDevShell { name = "ci"; };

          ciLint = makeCiDevShell {
            name = "ci-lint";
            packages = lintingDependencies;
          };

          ciCheckStyle = makeCiDevShell {
            name = "ci-check-style";
            packages = formattingDependencies;
          };

          ciCodegen = makeCiDevShell {
            name = "ci-codegen";
            packages = codeGenerationDependencies;
          };

          # So we can cache it and pin a version.
          gomod2nix = inputs'.gomod2nix.devShells.default;
        };
      };

      supportedSystems = with inputs.flake-utils.lib.system; [
        x86_64-linux
        x86_64-darwin
      ];

      isSupportedSystem = builtins.elem system supportedSystems;
    in
    optionalAttrs isSupportedSystem outputs;
}
