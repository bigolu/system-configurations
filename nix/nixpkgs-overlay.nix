let
  inherit (import ./flake-compat.nix) inputs;

  # Unlike the one in nixpkgs, this one merges sets recursively.
  composeManyExtensions =
    let
      foldr =
        op: nul: list:
        let
          len = builtins.length list;
          fold' = n: if n == len then nul else op (builtins.elemAt list n) (fold' (n + 1));
        in
        fold' 0;

      composeExtensions =
        f: g: final: prev:
        let
          inherit (prev.lib) recursiveUpdate;
          fApplied = f final prev;
          prev' = recursiveUpdate prev fApplied;
        in
        recursiveUpdate fApplied (g final prev');
    in
    foldr (x: y: composeExtensions x y) (_final: _prev: { });

  myOverlay =
    final: prev:
    let
      pins = import ./pins final;
      inherit (final.stdenv.hostPlatform) system;
      inherit (final.lib)
        recursiveUpdate
        recurseIntoAttrs
        optionalAttrs
        getExe
        escapeShellArgs
        ;
      inherit (final.stdenv) isLinux;

      filterPrograms =
        package: programsToKeep:
        let
          findFilters = builtins.concatMap (program: [
            "!"
            "-name"
            program
          ]) programsToKeep;
        in
        final.symlinkJoin {
          name = "${package.name}-partial";
          paths = [ package ];
          nativeBuildInputs = [ final.makeWrapper ];
          postBuild = ''
            cd $out/bin
            find . ${escapeShellArgs findFilters} -type f,l -exec rm -f {} +
          '';
        };
    in
    {
      parseNixShebang = prev.parseNixShebang.override { pkgs = final; };
      zerobox = final.linkFarm "zerobox" { "bin/zerobox" = "${pins.zerobox}/zerobox"; };
      inherit (inputs.nix-portable-home.legacyPackages.${system}) makePortableHome;
      bundlerRootless = inputs.nix-rootless-bundler.bundlers.${system}.default;

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

      __functor =
        self:
        # This file will be put on the NIX_PATH as 'nixpkgs' when we run cached-nix-shell
        # for mise tasks. This way all the packages we reference in the script will come
        # from here. Since nixpkgs is a function that returns a package set, this needs
        # to be a function as well.
        #
        # In order to have the nix CLI automatically call this function, the argument
        # must be a set with either no attributes or default values for all attributes.
        { }:
        self;
      # nix-shell uses `pkgs.runCommandCC` from nixpkgs to create the environment. We
      # set it to `runCommand` to make the closure smaller.
      pkgs = prev.pkgs // {
        runCommandCC = final.runCommand;
      };

      keyd = prev.keyd.overrideAttrs (old: {
        postInstall = old.postInstall + ''
          # TODO: keyd only links the service if /run/systemd/system exists[1]. I
          # should see if this can be changed.
          #
          # [1]: https://github.com/rvaiya/keyd/blob/9c758c0e152426cab3972256282bc7ee7e2f808e/Makefile#L51
          mkdir -p $out/lib/systemd/system
          cp keyd.service.in $out/lib/systemd/system/keyd.service
        '';
      });

      neovim =
        let
          oldNeovim = prev.neovim-unwrapped;

          dependencies = final.symlinkJoin {
            pname = "neovim-dependencies";
            version = "0.1.0";
            # to format comments
            paths = [ final.par ];
          };

          wrappedNeovim = final.symlinkJoin {
            pname = "my-${oldNeovim.pname}";
            inherit (oldNeovim) version;
            paths = [ oldNeovim ];
            nativeBuildInputs = [ final.makeWrapper ];
            postBuild = ''
              # PARINIT: The par manpage recommends using this value if you want
              # to start using par, but aren't familiar with how par works so
              # until I learn more, I'll use this value.
              wrapProgram $out/bin/nvim \
                --set PARINIT 'rTbgqR B=.\,?'"'"'_A_a_@ Q=_s>|' \
                --prefix PATH : ${dependencies}/bin
            '';
          };
        in
        # Merge with the original package to retain attributes like meta
        recursiveUpdate oldNeovim wrappedNeovim;

      partialPackages = recurseIntoAttrs (
        {
          xargs = filterPrograms final.findutils [ "xargs" ];
          ps = filterPrograms final.procps [ "ps" ];
          pkill = filterPrograms final.procps [ "pkill" ];
          look = filterPrograms final.util-linux [ "look" ];
          # toybox is a multi-call binary so we are going to delete everything besides the
          # toybox executable and the programs I need which are just symlinks to it.
          toybox = filterPrograms final.toybox [
            "toybox"
            "hostname"
            "strings"
          ];
        }
        // optionalAttrs isLinux {
          # The pstree from psmisc is preferred on linux for some reason:
          # https://github.com/NixOS/nixpkgs/blob/3dc440faeee9e889fe2d1b4d25ad0f430d449356/pkgs/applications/misc/pstree/default.nix#L36C8-L36C8
          pstree = filterPrograms final.psmisc [ "pstree" ];
        }
      );

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
              djvulibre
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
              --prefix PATH : ${dependencies}/bin \
              --prefix PATH : ${../dotfiles/ripgrep/bin}
          '';
        };

      speakerctl =
        let
          programName = "speakerctl";
        in
        final.writeShellApplication {
          name = programName;
          runtimeInputs = with final; [
            bash
            python3Packages.python-kasa
            coreutils
          ];
          meta.mainProgram = programName;
          text = ''
            # shellcheck disable=2016
            timeout "''${2:-10}s" bash -c '
              until kasa --alias plug "$1"; do
                true
              done
            ' -- "$1"
          '';
        };

      run-as-admin = final.writeShellApplication {
        name = "run-as-admin";
        runtimeInputs = [ final.coreutils ];
        text = ''
          # I want to run `darwin-rebuild/home-manager switch` and only input my
          # password once, but homebrew, rightly, invalidates the sudo cache before it
          # runs[1] so I have to input my password again for subsequent steps in the
          # rebuild. This script allows ANY command to be run without a password, for
          # the duration of the specified command. It also runs the specified command
          # as the user that launched this script, i.e. SUDO_USER, and not root.
          #
          # [1]: https://github.com/Homebrew/brew/pull/17694/commits/2adf25dcaf8d8c66124c5b76b8a41ae228a7bb02

          temp="$(mktemp)"
          if [[ $OSTYPE == linux* ]]; then
            group='sudo'
          else
            group='admin'
          fi
          echo "%$group		ALL = (ALL) NOPASSWD:SETENV: ALL" >"$temp"

          sudo chown --reference /etc/sudoers "$temp"
          sudo mv "$temp" /etc/sudoers.d/temp-config
          function remove_config {
            sudo rm /etc/sudoers.d/temp-config
          }
          trap remove_config EXIT

          sudo -u "$SUDO_USER" "$@"
        '';
      };

      # TODO: I shouldn't have to do this. Either nixpkgs should add the shell config
      # files or the tool itself should generate the files as part of its build script,
      # as direnv does[2].
      #
      # [2]: https://github.com/direnv/direnv/blob/29df55713c253e3da14b733da283f03485285cea/GNUmakefile
      zoxide =
        let
          oldZoxide = prev.zoxide;

          fishConfig =
            (final.runCommand "zoxide-fish-config-${oldZoxide.version}" { } ''
              config_directory="$out/share/fish/vendor_conf.d"
              mkdir -p "$config_directory"
              ${getExe oldZoxide} init --no-cmd fish > "$config_directory/zoxide.fish"
            '')
            // {
              inherit (oldZoxide) version;
            };

          newZoxide = final.symlinkJoin {
            inherit (oldZoxide) pname version;
            paths = [
              oldZoxide
              fishConfig
            ];
          };
        in
        # Merge with the original package to retain attributes like meta
        recursiveUpdate oldZoxide newZoxide;
    };
in
composeManyExtensions [
  inputs.direnv-shell-hooks.overlays.default
  inputs.git-auto-sync.overlays.default
  inputs.cached-nix-shell.overlays.default
  inputs.llm-agents.overlays.default
  inputs.nix-gl-host-rs.overlays.default
  myOverlay
]
