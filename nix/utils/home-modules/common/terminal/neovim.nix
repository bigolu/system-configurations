{
  pkgs,
  ...
}:
let
  inherit (pkgs) linkFarm myVimPluginPack neovim;
in
{
  home.packages = [
    neovim
    # Put the pack under share/ so neovim can automatically find it
    (linkFarm "my-vim-pack" { "share/nvim/site" = myVimPluginPack; })
  ];

  repository.xdg.configFile."nvim".source = "neovim";
}
