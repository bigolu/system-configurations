{
  pkgs,
  ...
}:
let
  inherit (pkgs) runCommand;

  # Put the pack under share/ so neovim can automatically find it
  vimPack = runCommand "my-vim-pack" { } ''
    pack_path="$out/share/nvim"
    mkdir -p "$pack_path"
    ln --symbolic ${pkgs.myVimPluginPack} "$pack_path/site"
  '';
in
{
  home.packages = [
    pkgs.neovim
    vimPack
  ];

  repository.symlink.xdg.configFile."nvim".source = "neovim";
}
