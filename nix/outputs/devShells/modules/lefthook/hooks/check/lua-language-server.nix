{ pkgs, lib, ... }:
let
  inherit (lib) getExe';
  inherit (pkgs) coreutils;

  ln = getExe' coreutils "ln";
  mkdir = getExe' coreutils "mkdir";
in
{
  devshell = {
    packages = with pkgs; [
      lua-language-server
    ];

    startup.lua.text = ''
      function symlink_if_target_changed {
        local -r target="$1"
        local -r symlink_path="$2"

        if [[ ! $target -ef $symlink_path ]]; then
          ${ln} --force --no-dereference --symbolic "$target" "$symlink_path"
        fi
      }

      prefix="$DEV_SHELL_STATE/lua-libraries"
      if [[ ! -d $prefix ]]; then
        ${mkdir} -p "$prefix"
      fi

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
  };
}
