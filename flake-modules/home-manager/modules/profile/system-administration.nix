{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) optionals;
  inherit (pkgs.stdenv) isLinux isDarwin;
  inherit (lib.attrsets) optionalAttrs;
in
{
  imports = [
    ../git.nix
    ../fzf.nix
    ../wezterm.nix
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
      coreutils-full
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
    ]
    ++ optionals isDarwin [
      pstree
    ];

  xdg = {
    configFile = {
      # TODO: I shouldn't have to do this. The programs should generate the files as
      # part of their build so they can be put in vendor_conf.d. See the direnv
      # package for an example of how this is done.
      "fish/conf.d/zoxide.fish".source =
        pkgs.runCommand "zoxide-config.fish" { }
          "${pkgs.zoxide}/bin/zoxide init --no-cmd fish > $out";
      "fish/conf.d/broot.fish".source =
        pkgs.runCommand "broot.fish" { }
          "${pkgs.broot}/bin/broot --print-shell-function fish > $out";
    };
  };

  repository = {
    symlink = {
      xdg.configFile =
        {
          "lsd".source = "lsd";
          "lesskey".source = "less/lesskey";
          "ripgrep/ripgreprc".source = "ripgrep/ripgreprc";
          "ssh/bootstrap.sh".source = "ssh/bootstrap.sh";
          "broot" = {
            source = "broot";
            # I'm recursively linking because I link into this directory in other
            # places.
            recursive = true;
          };
          "bat/config".source = "bat/config";
        }
        // optionalAttrs isLinux {
          "pipr/pipr.toml".source = "pipr/pipr.toml";
          "fish/conf.d/pipr.fish".source = "pipr/pipr.fish";
        };

      # The programs store files according to the XDG Base Directory spec[1] on Linux
      # and the Standard Directories guidelines[2] on macOS:
      #
      # [1]: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
      # [2]: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html#//apple_ref/doc/uid/TP40010672-CH2-SW6
      home.file = {
        "${
          if pkgs.stdenv.isLinux then ".config" else "Library/Application Support"
        }/tealdeer/config.toml".source = "tealdeer/config.toml";
        "${
          if pkgs.stdenv.isLinux then ".config" else "Library/Application Support"
        }/viddy.toml".source = "viddy/viddy.toml";
      };
    };
  };
}
