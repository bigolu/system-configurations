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
    # We could just always recreate the symlink, even if the target of the symlink
    # is the same, but since we use direnv, this would happen every time we load
    # the environment. This causes the following the problems:
    #   - It's slower so there would be a little lag when you enter the directory.
    #   - Some of these symlinks are being watched by programs and recreating them
    #     causes those programs to reload. For example, VS Code watches the symlink
    #     to Python.
    function symlink_if_target_changed {
      local -r target="$1"
      local -r symlink_path="$2"

      if [[ ! $target -ef $symlink_path ]]; then
        ln --force --no-dereference --symbolic "$target" "$symlink_path"
      fi
    }

    symlink_if_target_changed \
      ${pkgs.speakerctl.python} "''${direnv_layout_dir:-.direnv}/python"
  '';
}
