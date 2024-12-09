{
  lib,
  pkgs,
  ...
}:
let
  # TODO: Workaround for this issue:
  # https://github.com/junegunn/vim-plug/issues/1135
  tweakedVimPlug = pkgs.runCommand "tweaked-plug.vim" { } ''
    vim_plug=${lib.strings.escapeShellArgs [ "${pkgs.vimPlugins.vim-plug}/plug.vim" ]}
    target="len(s:glob(s:rtp(a:plug), 'plugin'))"
    # First grep so the build will error out if the string isn't present
    grep -q "$target" "$vim_plug"
    sed -e "s@$target@v:true@" <"$vim_plug" >"$out"
  '';
in
{
  xdg.dataFile = {
    "nvim/site/autoload/plug.vim".source = "${tweakedVimPlug}";

    "nvim/site/lua/nix-plugins.lua".text = ''
      return {
        ${lib.strings.concatMapStringsSep "\n" (
          name: ''["${name}"] = "${builtins.getAttr name pkgs.myVimPlugins}",''
        ) (builtins.attrNames pkgs.myVimPlugins)}
      }
    '';

    "nvim/site/parser".source =
      let
        allTreesitterParsers = pkgs.symlinkJoin {
          name = "all-treesitter-parsers";
          paths = pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies;
        };
      in
      "${allTreesitterParsers}/parser";
  };
}
