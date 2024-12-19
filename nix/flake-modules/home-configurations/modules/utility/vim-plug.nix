{
  lib,
  utils,
  pkgs,
  ...
}:
let
  inherit (builtins) getAttr attrNames;
  inherit (lib) escapeShellArgs concatMapStringsSep;
  inherit (pkgs) runCommand symlinkJoin myVimPlugins;
  inherit (utils) removeRecurseIntoAttrs;

  # TODO: Workaround for this issue:
  # https://github.com/junegunn/vim-plug/issues/1135
  tweakedVimPlug = runCommand "tweaked-plug.vim" { } ''
    vim_plug=${escapeShellArgs [ "${myVimPlugins.vim-plug}/plug.vim" ]}
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
        ${concatMapStringsSep "\n" (name: ''["${name}"] = "${getAttr name myVimPlugins}",'') (
          attrNames (removeRecurseIntoAttrs myVimPlugins)
        )}
      }
    '';

    "nvim/site/parser".source =
      let
        allTreesitterParsers = symlinkJoin {
          name = "all-treesitter-parsers";
          paths = myVimPlugins.nvim-treesitter.withAllGrammars.dependencies;
        };
      in
      "${allTreesitterParsers}/parser";
  };
}
