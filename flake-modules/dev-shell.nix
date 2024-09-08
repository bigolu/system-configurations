{
  lib,
  inputs,
  ...
}: {
  perSystem = {
    system,
    pkgs,
    inputs',
    ...
  }: let
    inherit (lib.attrsets) optionalAttrs;

    filterPrograms = package: programsToKeep: let
      findFilters = builtins.map (program: "! -name '${program}'") programsToKeep;
      findFiltersAsString = lib.strings.concatStringsSep " " findFilters;
    in
      pkgs.symlinkJoin {
        name = "${package.name}-partial";
        paths = [package];
        buildInputs = [pkgs.makeWrapper];
        postBuild = ''
          cd $out/bin
          find . ${findFiltersAsString} -type f,l -exec rm -f {} +
        '';
      };

    myMoreutils = filterPrograms pkgs.moreutils ["chronic" "vipe" "vidir" "sponge" "pee"];

    # Make a meta-package so we don't have a $PATH entry for each package
    tools = pkgs.symlinkJoin {
      name = "tools";
      paths = with pkgs; [
        # Languages
        bashInteractive
        go
        nix

        # Fixers and linters
        actionlint
        alejandra
        black
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

        # Version control
        git
        lefthook

        # Language servers
        efm-langserver
        nixd
        taplo

        # Bash script dependencies
        coreutils-full
        fd
        findutils
        gnugrep
        gnused
        jq # also used a linter for json
        ripgrep
        which
        yq-go
        ast-grep
        myMoreutils
        parallel

        # Miscellaneous
        doctoc
        just
        reviewdog

        # For paging the output of `just list`
        less
      ];

      # TODO: Nix should be able to link in prettier, I think it doesn't work
      # because the `prettier` is a symlink
      postBuild = ''
        cd $out/bin
        ln -s ${pkgs.nodePackages.prettier}/bin/prettier ./prettier
      '';
    };

    pluginNames = builtins.filter (name: name != "") (lib.strings.splitString "\n" (builtins.readFile "${inputs.self}/dotfiles/neovim/plugin-names.txt"));
    replaceDotsWithDashes = builtins.replaceStrings ["."] ["-"];
    pluginsByName =
      builtins.listToAttrs
      (map
        (
          pluginName: let
            getPackageForPlugin = builtins.getAttr pluginName;
            formattedPluginName = replaceDotsWithDashes pluginName;
            package =
              if builtins.hasAttr pluginName pkgs.vimPlugins
              then getPackageForPlugin pkgs.vimPlugins
              else if builtins.hasAttr formattedPluginName pkgs.vimPlugins
              then (builtins.getAttr "overrideAttrs" (builtins.getAttr formattedPluginName pkgs.vimPlugins)) (_old: {pname = pluginName;})
              else abort "Failed to find vim plugin: ${pluginName}";
          in {
            name = pluginName;
            value = package;
          }
        )
        pluginNames);

    luaLsLibraries = pkgs.symlinkJoin {
      name = "lua-ls-libraries";
      paths = [];
      postBuild = ''
        cd $out
        ln -s ${lib.escapeShellArg (pkgs.linkFarm "plugins" pluginsByName)} ./plugins
        ln -s ${lib.escapeShellArg inputs.neodev-nvim}/types/nightly ./neodev
        ln -s ${lib.escapeShellArg pkgs.neovim}/share/nvim/runtime ./nvim-runtime
      '';
    };

    outputs = {
      # TODO: The devShell contains a lot of environment variables that are irrelevant
      # to our development environment, but Nix is working on a solution to
      # that: https://github.com/NixOS/nix/issues/7501
      devShells.default = pkgs.mkShellNoCC {
        packages = [
          tools
        ];
        shellHook = ''
          # For nixd
          export NIX_PATH=${lib.escapeShellArg inputs.nixpkgs}

          export LUA_LS_LIBRARIES=${lib.escapeShellArg luaLsLibraries}
          export TREESITTER_PARSERS=${lib.escapeShellArg pkgs.vimPlugins.treesitter-parsers}/parser
        '';
      };

      devShells.gomod2nix = inputs'.gomod2nix.devShells.default;
    };

    supportedSystems = with inputs.flake-utils.lib.system; [x86_64-linux x86_64-darwin];
    isSupportedSystem = builtins.elem system supportedSystems;
  in
    optionalAttrs isSupportedSystem outputs;
}
