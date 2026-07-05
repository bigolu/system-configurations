{ lib, pkgs, ... }:
let
  inherit (lib)
    optionals
    optionalAttrs
    hm
    getExe
    ;
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
in
{
  imports = [
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
      bat
      coreutils
      gnused
      run-as-admin
      less
      rsync
      gawkInteractive
      gnutar
    ]
    ++ optionals isLinux [
      trashy
      pipr
      # The pstree from psmisc is preferred on linux for some reason:
      # https://github.com/NixOS/nixpkgs/blob/3dc440faeee9e889fe2d1b4d25ad0f430d449356/pkgs/applications/misc/pstree/default.nix#L36C8-L36C8
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
      "bat".source = "bat";
    }
    // optionalAttrs isLinux {
      "pipr/pipr.toml".source = "pipr/pipr.toml";
      "isd/config.yaml".source = "isd/config.yaml";
    };

    # The programs store files according to the XDG Base Directory spec[1] on Linux
    # and the Standard Directories guidelines[2] on macOS:
    #
    # [1]: https://specifications.freedesktop.org/basedir-spec/latest/
    # [2]: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html#//apple_ref/doc/uid/TP40010672-CH2-SW6
    home.file = {
      "${if isLinux then ".config" else "Library/Application Support"}/tealdeer/config.toml".source =
        "tealdeer/config.toml";
      "${if isLinux then ".config" else "Library/Application Support"}/viddy.toml".source =
        "viddy/viddy.toml";
    };
  };

  home.activation.batSetup = hm.dag.entryAfter [ "linkGeneration" ] ''
    ${getExe pkgs.bat} cache --build 1>/dev/null 2>&1
  '';
}
