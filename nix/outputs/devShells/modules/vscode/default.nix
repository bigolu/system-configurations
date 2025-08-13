{ pkgs, ... }:
{
  imports = [
    ./efm-language-server.nix
  ];

  packages = with pkgs; [
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
  shellHook = ''
    symlink="''${direnv_layout_dir:-.direnv}/python"
    target=${pkgs.speakerctl.python}
    # VS Code automatically reloads when the symlink to Python changes so I don't
    # want to recreate it unless it will point somewhere else.
    #
    # PERF: We could just always run `ln`, but checking if the symlink has the right
    # target is faster. The `shellHook` should be fast since `direnv` will run it.
    if [[ ! $symlink -ef $target ]]; then
      ln --force --no-dereference --symbolic "$target" "$symlink"
    fi
  '';
}
