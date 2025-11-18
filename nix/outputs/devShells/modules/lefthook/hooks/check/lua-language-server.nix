{ pkgs, ... }:
let
  inherit (pkgs) linkFarm;
in
{
  devshell = {
    packages = with pkgs; [
      lua-language-server
    ];
  };

  env = [
    {
      name = "LUA_LIBRARY_NIX";
      value = linkFarm "lua-libraries" {
        neovim-runtime = "${pkgs.neovim}/share/nvim/runtime";
        neovim-plugins = "${pkgs.myVimPluginPack}/pack/bigolu/start";
      };
    }
    {
      name = "LUA_LIBRARY_HAMMERSPOON";
      eval = "$HOME/.hammerspoon/Spoons/EmmyLua.spoon/annotations";
    }
  ];
}
