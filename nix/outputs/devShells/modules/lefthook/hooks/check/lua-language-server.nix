{ pkgs, ... }:
{
  devshell = {
    packages = with pkgs; [
      lua-language-server
    ];
  };

  env = [
    {
      name = "LUA_LIBRARY_NEOVIM_RUNTIME";
      eval = "$HOME/.nix-profile/share/nvim/runtime";
    }
    {
      name = "LUA_LIBRARY_NEOVIM_PLUGINS";
      eval = "$HOME/.nix-profile/share/nvim/site/pack/bigolu/start";
    }
    {
      name = "LUA_LIBRARY_HAMMERSPOON";
      eval = "$HOME/.hammerspoon/Spoons/EmmyLua.spoon/annotations";
    }
  ];
}
