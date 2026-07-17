{ lib, pkgs, ... }:
let
  inherit (lib) optionals optionalAttrs;
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;

  configDir = if isLinux then ".config" else "Library/Application Support";
in
{
  imports = [
    ./bat.nix
    ./fish.nix
    ./fzf.nix
    ./ghostty.nix
    ./git.nix
    ./neovim.nix
    ./ripgrep-all.nix
  ];

  home.packages =
    with pkgs;
    [
      fd
      jq
      ijq
      lsd
      moreutils
      ripgrep
      tealdeer
      viddy
      zoxide
      file
      chase
      gnugrep
      broot
      hyperfine
      timg
      gzip
      wget
      which
      # toybox is a multi-call binary so we are going to delete everything besides the
      # toybox executable and the programs I need which are just symlinks to it.
      (filterPrograms toybox [
        "toybox"
        "hostname"
        "strings"
      ])
      (filterPrograms findutils [ "xargs" ])
      (filterPrograms procps [ "ps" ])
      ast-grep
      lesspipe
      diffoscopeMinimal
      coreutils
      gnused
      less
      rsync
      gawkInteractive
      gnutar
    ]
    ++ optionals isLinux [
      trashy
      pipr
      (filterPrograms psmisc [ "pstree" ])
      strace
      inotify-info
      isd
    ]
    ++ optionals isDarwin [ pstree ];

  fileWrapper = {
    xdg.configFile = {
      "lsd".source = "lsd";
      "lesskey".source = "less/lesskey";
      "ripgrep/ripgreprc".source = "ripgrep/ripgreprc";
      "broot".source = "broot";
    }
    // optionalAttrs isLinux {
      "pipr/pipr.toml".source = "pipr/pipr.toml";
      "isd/config.yaml".source = "isd/config.yaml";
    };

    home.file = {
      "${configDir}/tealdeer/config.toml".source = "tealdeer/config.toml";
      "${configDir}/viddy.toml".source = "viddy/viddy.toml";
    };
  };
}
