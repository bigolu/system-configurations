{ pkgs, ... }:
{
  imports = [
    # For extension "llllvvuu.llllvvuu-glspc"
    {
      devshell.packages = with pkgs; [
        efm-langserver

        # These are used in the efm-langserver config
        coreutils
        # efm-langserver launches commands with`sh`
        dash
      ];
    }

    # For extension "rogalmic.bash-debug"
    {
      # It needs bash, cat, mkfifo, rm, and pkill
      devshell.packages = with pkgs; [
        bash
        coreutils
        partialPackages.pkill
      ];
    }
  ];

  devshell.packages = with pkgs; [
    # For extension "jnoortheen.nix-ide"
    nixd
    # For extension "ndonfris.fish-lsp"
    fish-lsp
    # For extension "golang.go"
    gopls
  ];

  # For extension "ms-python.python". Link python to a stable location so I don't
  # have to update "python.defaultInterpreterPath" in settings.json when the nix
  # store path for python changes.
  devshell.startup.vscode.text = ''
    symlink="$DEV_SHELL_STATE/python"
    target=${pkgs.speakerctl.python}
    # VS Code automatically reloads when the symlink to Python changes so I don't
    # want to recreate it unless it will point somewhere else.
    if [[ ! $symlink -ef $target ]]; then
      ln --force --no-dereference --symbolic "$target" "$symlink"
    fi
  '';
}
