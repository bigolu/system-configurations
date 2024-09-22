{
  lib,
  inputs,
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

      utilities = import ./utilities.nix { inherit pkgs; };
      inherit (utilities) makeDevShell makeCiDevShell;

      scriptDependencyInfo = import ./scripts.nix {
        inherit pkgs;
        inherit (inputs) self;
      };
      scripts = scriptDependencyInfo.dependenciesByName;

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

      linters = with pkgs; [
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

        # Not actually a linter, but it reports the errors
        reviewdog

        # TODO: If the YAML language server gets a CLI I should use that instead:
        # https://github.com/redhat-developer/yaml-language-server/issues/535
        yamllint
      ];

      formatters = with pkgs; [
        nixfmt-rfc-style
        fish # for fish_indent
        nodePackages.prettier
        shfmt
        stylua
        treefmt
        just
        go # for gofmt
        taplo
        ruff
      ];

      vsCodeDependencies =
        with pkgs;
        [
          go
          efm-langserver
          nixd
        ]
        # for efm-langserver
        ++ linters;

      taskRunnerDependencies = with pkgs; [
        just
        less # For paging the output of `just list`
      ];

      versionControlDependencies = with pkgs; [
        gitMinimal
        lefthook
      ];

      languageDependencies = with pkgs; [
        nix
        bashInteractive
        go
      ];

      outputs = {
        packages.nix-develop-gha = inputs'.nix-develop-gha.packages.default;

        devShells = {
          default = makeDevShell {
            name = "local-dependencies";
            packages =
              vsCodeDependencies
              ++ linters
              ++ formatters
              ++ scriptDependencyInfo.allDependencies
              ++ taskRunnerDependencies
              ++ versionControlDependencies
              ++ languageDependencies;
            shellHook =
              ''
                # For nixd
                export NIX_PATH='nixpkgs='${lib.escapeShellArg inputs.nixpkgs}

                # Even though I never use the scripts made by resholve, I still
                # want resholve to make them so it can verify that I specified
                # their dependencies properly. To force the package containing
                # the resholve scripts to be evaluated, I'm adding a reference
                # to the package here.
                # ${lib.escapeShellArg scriptDependencyInfo.validationPackage}
              ''
              + linkLuaLsLibrariesHook;
          };

          ci = makeCiDevShell { name = "ci-dependencies"; };

          ciLint = makeCiDevShell {
            name = "ci-lint-dependencies";
            packages = linters;
            scripts = with scripts; [ qa-qa ];
            shellHook = linkLuaLsLibrariesHook;
          };

          ciCheckStyle = makeCiDevShell {
            name = "ci-check-style-dependencies";
            packages = [ pkgs.treefmt ] ++ formatters;
          };

          ciCodegen =
            let
              codegen-scripts = lib.attrsets.foldlAttrs (
                acc: name: script:
                acc ++ lib.lists.optionals (lib.hasPrefix "code-generation" name) [ script ]
              ) [ ] scripts;
            in
            makeCiDevShell {
              name = "ci-codegen-dependencies";
              scripts = [ scripts.qa-qa ] ++ codegen-scripts;
            };

          ciRenovate = makeCiDevShell {
            name = "ci-renovate-dependencies";
            scripts = with scripts; [
              ci-set-nix-direnv-hash
              code-generation-generate-gomod2nix-lock
            ];
          };

          ciAutoMerge = makeCiDevShell {
            name = "ci-auto-merge-dependencies";
            scripts = with scripts; [ ci-auto-merge ];
          };

          ciTest = makeCiDevShell {
            name = "ci-test-dependencies";
            scripts = with scripts; [ test ];
          };

          # So we can cache it
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
