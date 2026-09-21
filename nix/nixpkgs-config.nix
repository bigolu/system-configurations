let
  inherit (builtins) elem concatMap;

  inherit (import ../.) inputs;

  myOverlay =
    final: prev:
    let
      inherit (final.stdenv.hostPlatform) system;
      inherit (final.lib) recursiveUpdate getExe escapeShellArgs;
    in
    {
      inherit (inputs.nix-portable-home.legacyPackages.${system}) makePortableHome;
      bundlerRootless = inputs.nix-rootless-bundler.bundlers.${system}.default;

      filterPrograms =
        package: programsToKeep:
        let
          findFilters = concatMap (program: [
            "!"
            "-name"
            program
          ]) programsToKeep;
        in
        final.symlinkJoin {
          name = "${package.pname}-partial-${package.version}";
          paths = [ package ];
          nativeBuildInputs = [ final.makeWrapper ];
          postBuild = ''
            cd $out/bin
            find . ${escapeShellArgs findFilters} -type f,l -exec rm -f {} +
          '';
        };

      # Allows all commands launched through it to use `sudo` without a
      # password. This tool intentionally doesn't invoke the given command with
      # `sudo` to account for commands like `system-manager --sudo` where
      # `system-manager` will run `sudo` itself.
      s =
        let
          sudoConfig = final.runCommand "sudo-config" {
            src = final.writeText "sudo-config" ''
              %${if final.stdenv.hostPlatform.isLinux then "sudo" else "admin"}		ALL = (ALL) NOPASSWD:SETENV: ALL
            '';
          } "${final.sudo}/sbin/visudo -cf $src && cp $src $out";
        in
        final.writeShellApplication {
          name = "s";
          runtimeInputs = [ final.coreutils ];
          text = ''
            temp="$(mktemp)"
            cp ${sudoConfig} "$temp"
            sudo chown --reference /etc/sudoers "$temp"
            sudo mv "$temp" /etc/sudoers.d/temp-config
            function remove_config {
              # -f accounts for this being run concurrently
              sudo rm -f /etc/sudoers.d/temp-config
            }
            trap remove_config EXIT

            # Retain the current user since this command shouldn't change to the
            # root user, the commands launched through it with sudo should.
            sudo -u "$SUDO_USER" "$@"
          '';
        };

      lixPackageSet =
        let
          lixPackageSet = final.lixPackageSets.latest;
        in
        lixPackageSet
        // {
          # TODO: Remove this when comma is added to lixPackageSets[1].
          #
          # [1]: https://github.com/NixOS/nixpkgs/pull/462022
          comma = prev.comma.override { nix = lixPackageSet.lix; };
        };

      keyd = prev.keyd.overrideAttrs (old: {
        postInstall = old.postInstall + ''
          # TODO: keyd only links the service if /run/systemd/system exists or
          # the environment variable `FORCE_SYSTEMD` is set[1]. I should have
          # nixpkgs set this variable.
          #
          # [1]: https://github.com/rvaiya/keyd/blob/f564288ac2b19d2305a5b39023c474805ff8fce5/Makefile#L52
          mkdir -p $out/lib/systemd/system
          cp keyd.service.in $out/lib/systemd/system/keyd.service
        '';
      });

      # TODO: Consider upstreaming an option to include all the community
      # adapters[1].
      #
      # [1]: https://github.com/phiresky/ripgrep-all/discussions/199
      ripgrep-all =
        let
          old-ripgrep-all = prev.ripgrep-all;
          dependencies = final.symlinkJoin {
            pname = "ripgrep-all-dependencies";
            version = "0.1.0";
            paths = with final; [
              xlsx2csv
              fastgron
              tesseract
            ];
          };
        in
        final.symlinkJoin {
          pname = "my-${old-ripgrep-all.pname}";
          inherit (old-ripgrep-all) version;
          paths = [ prev.ripgrep-all ];
          nativeBuildInputs = [ final.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/rga \
              --prefix PATH : ${dependencies}/bin
          '';
        };

      speakerctl = final.writeShellApplication rec {
        name = "speakerctl";
        runtimeInputs = with final; [
          bash
          python3Packages.python-kasa
          coreutils
        ];
        meta.mainProgram = name;
        text = ''
          # shellcheck disable=2016
          timeout "''${2:-10}s" bash -c '
            until kasa --alias plug "$1"; do
              true
            done
          ' -- "$1"
        '';
      };

      # TODO: I shouldn't have to do this. Either nixpkgs should add the shell config
      # files or the tool itself should generate the files as part of its build script,
      # as direnv does[2]. zoxide includes autocompete in its build script, but not config.
      #
      # [2]: https://github.com/direnv/direnv/blob/29df55713c253e3da14b733da283f03485285cea/GNUmakefile
      zoxide =
        let
          oldZoxide = prev.zoxide;

          nushellConfig = final.runCommand "zoxide-nushell-config-${oldZoxide.version}" { } ''
            config_directory="$out/share/nushell/vendor/autoload"
            mkdir -p "$config_directory"
            ${getExe oldZoxide} init --no-cmd nushell > "$config_directory/zoxide-config.nu"
          '';

          newZoxide = final.symlinkJoin {
            inherit (oldZoxide) pname version;
            paths = [
              oldZoxide
              nushellConfig
            ];
          };
        in
        # Merge with the original package to retain attributes like meta
        recursiveUpdate oldZoxide newZoxide;

      # TODO: nixpkgs should do this
      broot =
        let
          oldBroot = prev.broot;

          nushellConfig = final.runCommand "broot-nushell-config-${oldBroot.version}" { } ''
            config_directory="$out/share/nushell/vendor/autoload"
            mkdir -p "$config_directory"
            {
              # TODO: broot should be making a module
              echo 'module br {'
              ${getExe oldBroot} --print-shell-function nushell
              echo
              echo '}'
              echo 'export use br *'
            } > "$config_directory/br.nu"
          '';

          newBroot = final.symlinkJoin {
            inherit (oldBroot) pname version;
            paths = [
              oldBroot
              nushellConfig
            ];
          };
        in
        # Merge with the original package to retain attributes like meta
        recursiveUpdate oldBroot newBroot;
    };

  llmAgentsOverlay = final: _: {
    llm-agents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
  };

  nixpkgsMultiverseOverlay = final: _: {
    multiverse =
      inputs.nixpkgs-multiverse.legacyPackages.${final.stdenv.hostPlatform.system}.fast.versions;
  };
in
{
  config.allowUnfreePredicate = pkg: elem pkg.pname [ "vscode" ];

  overlays = [
    inputs.git-auto-sync.overlays.default
    inputs.git-auto-check.overlays.default
    inputs.nix-scene.overlays.default
    llmAgentsOverlay
    nixpkgsMultiverseOverlay
    myOverlay
  ];
}
