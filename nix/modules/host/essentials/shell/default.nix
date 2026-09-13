{
  _class,
  lib,
  pkgs,
  myUtils,
  ...
}:
{
  homeManager =
    let
      inherit (lib) optionals optionalAttrs getExe;
      inherit (pkgs) runCommand buildEnv;
      inherit (myUtils) programConfigRoot;
      inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;

      configDir = if isLinux then ".config" else "Library/Application Support";

      fzfWithoutShellConfig = buildEnv {
        name = "fzf-without-shell-config";
        paths = [ pkgs.fzf ];
        pathsToLink = [
          "/bin"
          "/share/man"
        ];
      };
    in
    {
      imports = [
        ./git.nix
        ./neovim.nix
      ];

      # The `man` in nixpkgs is only intended to be used on NixOS[1].
      #
      # TODO: I should upstream this.
      #
      # [1]: https://github.com/nix-community/home-manager/issues/432#issuecomment-434498787
      programs.man.package = null;

      home.packages =
        with pkgs;
        [
          # toybox is a multi-call binary so we are going to delete everything besides the
          # toybox executable and the programs I need which are just symlinks to it.
          (filterPrograms toybox [
            "toybox"
            "strings"
          ])
          (filterPrograms git-extras [
            "git-wip"
            "git-info"
            "git-delete-merged-branches"
          ])
          (filterPrograms procps [ "ps" ])
          (nushell.withPlugins (with nushellPlugins; [ formats ]))
          ast-grep
          bat
          broot
          chase
          coreutils
          diffoscopeMinimal
          fd
          file
          fish
          fzfWithoutShellConfig
          gnutar
          gzip
          less
          lesspipe
          ripgrep
          ripgrep-all
          rsync
          tealdeer
          timg
          viddy
          zoxide
        ]
        ++ optionals isLinux [
          (filterPrograms psmisc [ "pstree" ])
          inotify-info
          isd
          strace
        ]
        ++ optionals isDarwin [ pstree ];

      xdg.cacheFile.bat = {
        recursive = true;
        source = runCommand "bat-cache" { } ''
          BAT_CACHE_PATH=$out BAT_CONFIG_DIR=${programConfigRoot + /bat} \
            ${getExe pkgs.bat} cache --build
        '';
      };

      fileWrapper = {
        xdg = {
          configFile = {
            "lesskey".source = "less/lesskey";
            "ripgrep/ripgreprc".source = "ripgrep/ripgreprc";
            "broot".source = "broot";
            "bat".source = "bat";
            "fzf/fzfrc.txt".source = "fzf/fzfrc.txt";
            "tealdeer/config.toml".source = "tealdeer/config.toml";
            "nushell/autoload".source = "nushell/autoload";
          }
          // optionalAttrs isLinux { "isd/config.yaml".source = "isd/config.yaml"; };

          # fzf will fail if the history file's directory doesn't exist.
          #
          # I could use systemd-tmpfile, but that wouldn't work in the portable shell.
          dataFile."fzf/keep".source = pkgs.emptyFile;

          executable."fzf" = {
            source = "fzf/bin";
            recursive = true;
          };
        };

        home.file = {
          "${configDir}/viddy.toml".source = "viddy/viddy.toml";
          "${configDir}/ripgrep-all/config.jsonc".source = "ripgrep/config.jsonc";
        };
      };
    };
}
.${toString _class}
