{ pkgs, ... }:
{
  imports = [
    ./efm-language-server.nix
  ];

  devshell.packages = with pkgs; [
    # For "jnoortheen.nix-ide"
    nixd

    # For "rogalmic.bash-debug". It needs bash, cat, mkfifo, rm, and pkill
    bash
    coreutils
    partialPackages.pkill

    # For ndonfris.fish-lsp
    fish-lsp
  ];

  # For "ms-python.python". Link python to a stable location so I don't have to
  # update "python.defaultInterpreterPath" in settings.json when the nix store path
  # for python changes.
  devshell.startup.vscode.text = ''
    symlink="''${direnv_layout_dir:-.direnv}/python"
    target=${pkgs.speakerctl.python}
    # VS Code automatically reloads when the symlink to Python changes so I don't
    # want to recreate it unless it will point somewhere else.
    if [[ ! $symlink -ef $target ]]; then
      ln --force --no-dereference --symbolic "$target" "$symlink"
    fi
  '';
}
