{ pkgs, ... }:
{
  packages = with pkgs; [
    lua-language-server
  ];

  shellHook = ''
    # perf: We could just always run `mkdir -p`, but since we use direnv, this
    # would happen every time we load the environment and it's slower than checking
    # if the directory exists.
    function mkdir_if_missing {
      local -r dir="$1"

      if [[ ! -d $dir ]]; then
        mkdir -p "$dir"
      fi
    }

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

    prefix="''${direnv_layout_dir:-.direnv}/lua-libraries"
    mkdir_if_missing "$prefix"

    symlink_if_target_changed \
      ${pkgs.myVimPluginPack}/pack/bigolu/start "$prefix/neovim-plugins"
    symlink_if_target_changed \
      ${pkgs.neovim}/share/nvim/runtime "$prefix/neovim-runtime"

    hammerspoon_annotations="$HOME/.hammerspoon/Spoons/EmmyLua.spoon/annotations"
    if [[ -e $hammerspoon_annotations ]]; then
      symlink_if_target_changed \
        "$hammerspoon_annotations" "$prefix/hammerspoon-annotations"
    fi
  '';
}
