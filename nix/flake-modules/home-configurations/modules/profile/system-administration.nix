{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    optionals
    optionalAttrs
    hm
    getExe
    ;
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  imports = [
    ../git.nix
    ../fzf.nix
    ../terminal.nix
    ../ripgrep-all.nix
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
      partialPackages.toybox
      partialPackages.xargs
      partialPackages.ps
      ast-grep
      lesspipe
      diffoscopeMinimal
      bat
      coreutils
      gnused
      runAsAdmin
      less
      rsync
      gawkInteractive
    ]
    ++ optionals isLinux [
      trashy
      pipr
      catp
      partialPackages.pstree
      cntr
      strace
      inotify-info
      isd
    ]
    ++ optionals isDarwin [
      pstree
    ];

  repository = {
    symlink = {
      xdg.configFile =
        {
          "lsd".source = "lsd";
          "lesskey".source = "less/lesskey";
          "ripgrep/ripgreprc".source = "ripgrep/ripgreprc";
          "ssh/bootstrap.sh".source = "ssh/bootstrap.sh";
          "broot".source = "broot";
          "bat".source = "bat";
        }
        // optionalAttrs isLinux {
          "pipr/pipr.toml".source = "pipr/pipr.toml";
        };

      # The programs store files according to the XDG Base Directory spec[1] on Linux
      # and the Standard Directories guidelines[2] on macOS:
      #
      # [1]: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
      # [2]: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html#//apple_ref/doc/uid/TP40010672-CH2-SW6
      home.file = {
        "${if isLinux then ".config" else "Library/Application Support"}/tealdeer/config.toml".source =
          "tealdeer/config.toml";
        "${if isLinux then ".config" else "Library/Application Support"}/viddy.toml".source =
          "viddy/viddy.toml";
      };
    };
  };

  home.activation.batSetup = hm.dag.entryAfter [
    "linkGeneration"
  ] "${getExe pkgs.bat} cache --build 1>/dev/null 2>&1";
}
