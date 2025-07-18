{
  pkgs,
  ...
}:
let
  inherit (pkgs) runCommand myVimPluginPack neovim;

  # Put the pack under share/ so neovim can automatically find it
  vimPack = runCommand "my-vim-pack" { } ''
    pack_path="$out/share/nvim"
    mkdir -p "$pack_path"
    ln --symbolic ${myVimPluginPack} "$pack_path/site"
  '';
in
{
  home.packages = [
    neovim
    vimPack
  ];

  repository.xdg.configFile."nvim".source = "neovim";
}
