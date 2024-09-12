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

      lintersAndFixers = with pkgs; [
        actionlint
        nixfmt-rfc-style
        deadnix
        fish # for fish_indent, also used as logic linter
        lychee
        nodePackages.prettier
        renovate # for renovate-config-validator
        shellcheck
        shfmt
        statix
        stylua
        treefmt
        usort
        # TODO: If the YAML language server gets a CLI I should use that instead:
        # https://github.com/redhat-developer/yaml-language-server/issues/535
        yamllint
        ltex-ls # for ltex-cli
        markdownlint-cli2
        desktop-file-utils
        lua-language-server
        golangci-lint
        config-file-validator
        taplo
        ruff
        reviewdog
      ];

      commonShellDeps = with pkgs; [
        coreutils
        fd
        findutils
        gnugrep
        gnused
        jq
        ripgrep
        which
        nix
        gitMinimal
      ];

      # Make a meta-package so we don't have a $PATH entry for each package
      local = pkgs.symlinkJoin {
        name = "tools";
        paths =
          with pkgs;
          [
            # Languages
            bashInteractive
            # For VS Code Go extension
            go
            ast-grep

            # Version control
            lefthook

            # Language servers for VS Code
            efm-langserver
            nixd

            # For linter
            yq-go
            parallel

            # Miscellaneous
            doctoc
            just
            # For paging the output of `just list`
            less
          ]
          ++ lintersAndFixers
          ++ commonShellDeps;

        # TODO: Nix should be able to link in prettier, I think it doesn't work
        # because the `prettier` is a symlink
        postBuild = ''
          cd $out/bin
          ln -s ${pkgs.nodePackages.prettier}/bin/prettier ./prettier
        '';
      };

      ci = pkgs.symlinkJoin {
        name = "tools";
        paths = commonShellDeps;
      };

      ciLint = pkgs.symlinkJoin {
        name = "tools";
        paths = commonShellDeps ++ lintersAndFixers;

        # TODO: Nix should be able to link in prettier, I think it doesn't work
        # because the `prettier` is a symlink
        postBuild = ''
          cd $out/bin
          ln -s ${pkgs.nodePackages.prettier}/bin/prettier ./prettier
        '';
      };

      ciCodegen = pkgs.symlinkJoin {
        name = "tools";
        paths =
          commonShellDeps
          ++ (with pkgs; [
            ast-grep
            doctoc
            go
          ]);
      };

      ciRenovate = pkgs.symlinkJoin {
        name = "tools";
        paths =
          commonShellDeps
          ++ (with pkgs; [
            fish
          ]);
      };

      pluginNames = builtins.filter (name: name != "") (
        lib.strings.splitString "\n" (builtins.readFile "${inputs.self}/dotfiles/neovim/plugin-names.txt")
      );
      replaceDotsWithDashes = builtins.replaceStrings [ "." ] [ "-" ];
      pluginsByName = builtins.listToAttrs (
        map (
          pluginName:
          let
            getPackageForPlugin = builtins.getAttr pluginName;
            formattedPluginName = replaceDotsWithDashes pluginName;
            package =
              if builtins.hasAttr pluginName pkgs.vimPlugins then
                getPackageForPlugin pkgs.vimPlugins
              else if builtins.hasAttr formattedPluginName pkgs.vimPlugins then
                (builtins.getAttr "overrideAttrs" (builtins.getAttr formattedPluginName pkgs.vimPlugins)) (_old: {
                  pname = pluginName;
                })
              else
                abort "Failed to find vim plugin: ${pluginName}";
          in
          {
            name = pluginName;
            value = package;
          }
        ) pluginNames
      );

      luaLsLibraries = pkgs.symlinkJoin {
        name = "lua-ls-libraries";
        paths = [ ];
        postBuild = ''
          cd $out
          ln -s ${lib.escapeShellArg (pkgs.linkFarm "plugins" pluginsByName)} ./plugins
          ln -s ${lib.escapeShellArg inputs.neodev-nvim}/types/nightly ./neodev
          ln -s ${lib.escapeShellArg pkgs.neovim}/share/nvim/runtime ./nvim-runtime
        '';
      };

      # TODO: The devShells contain a lot of environment variables that are irrelevant
      # to our development environment, but Nix is working on a solution to
      # that: https://github.com/NixOS/nix/issues/7501
      outputs = {
        devShell = {
          default = pkgs.mkShellNoCC {
            packages = [
              local
            ];
            shellHook = ''
              # For nixd
              export NIX_PATH=${lib.escapeShellArg inputs.nixpkgs}

              export LUA_LS_LIBRARIES=${lib.escapeShellArg luaLsLibraries}
              export TREESITTER_PARSERS=${lib.escapeShellArg pkgs.vimPlugins.treesitter-parsers}/parser
            '';
          };

          ci = pkgs.mkShellNoCC {
            packages = [
              ci
            ];
          };

          ciLint = pkgs.mkShellNoCC {
            packages = [
              ciLint
            ];
            shellHook = ''
              export LUA_LS_LIBRARIES=${lib.escapeShellArg luaLsLibraries}
            '';
          };

          ciCodegen = pkgs.mkShellNoCC {
            packages = [
              ciCodegen
            ];
            shellHook = ''
              export TREESITTER_PARSERS=${lib.escapeShellArg pkgs.vimPlugins.treesitter-parsers}/parser
            '';
          };

          ciRenovate = pkgs.mkShellNoCC {
            packages = [
              ciRenovate
            ];
          };

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
