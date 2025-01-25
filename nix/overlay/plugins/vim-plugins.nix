{
  inputs,
  makePluginPackages,
  utils,
}:
final: prev:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib)
    splitString
    pipe
    init
    nameValuePair
    ;
  inherit (builtins)
    elemAt
    hasAttr
    listToAttrs
    substring
    stringLength
    readFile
    ;
  inherit (utils) projectRoot toNixpkgsAttr toNixpkgsPname;

  vimPluginsFromFlake =
    let
      vimPluginRepositoryPrefix = "vim-plugin-";

      vimPluginBuilder =
        repositoryName: repositorySourceCode: date:
        let
          nixpkgsAttrName = toNixpkgsAttr repositoryName;
        in
        if hasAttr nixpkgsAttrName prev.vimPlugins then
          prev.vimPlugins.${nixpkgsAttrName}.overrideAttrs (_old: {
            version = date;
            src = repositorySourceCode;
          })
        else
          final.vimUtils.buildVimPlugin {
            pname = toNixpkgsPname repositoryName;
            version = date;
            src = repositorySourceCode;
          };
    in
    makePluginPackages vimPluginRepositoryPrefix vimPluginBuilder;

  myVimPlugins =
    let
      nameOverrides = {
        # TODO: Per nixpkgs' package naming rules, they should lowercase these:
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#package-naming
        "Navigator.nvim" = "Navigator-nvim";
        "SchemaStore.nvim" = "SchemaStore-nvim";
      };

      getPackage =
        pluginName:
        let
          nixpkgsAttrName = nameOverrides.${pluginName} or (toNixpkgsAttr pluginName);
        in
        final.vimPlugins.${nixpkgsAttrName}
          or (abort "Failed to find package for vim plugin: ${pluginName}. Package name used: ${nixpkgsAttrName}");
    in
    pipe
      (final.runCommand "neovim-plugin-names"
        {
          nativeBuildInputs = with final; [
            ast-grep
            jq
          ];
        }
        ''
          # shellcheck disable=SC2016
          # The dollar signs are for ast-grep
          #
          # I'm using jq instead of builtins.fromJSON because Nix doesn't allow
          # certain strings to have references to the Nix store[1] and one of the
          # keys in this JSON contains the path of the file with the matched text.
          #
          # [1]: https://discourse.nixos.org/t/not-allowed-to-refer-to-a-store-path-error/5226/4
          ast-grep --lang lua --pattern 'Plug($ARG $$$)' --json=compact ${
            projectRoot + /dotfiles/neovim/lua
          } \
            | jq --raw-output '.[].metaVariables.single.ARG.text' \
            > $out
        ''
      )
      [
        readFile
        (splitString "\n")
        # The file ends in a newline so the last line will be empty
        init
        # *<author>/<plugin_name>" -> <plugin_name>"
        (map (authorPlugin: elemAt (splitString "/" authorPlugin) 1))
        # <plugin_name>" -> <plugin_name>
        (map (string: substring 0 ((stringLength string) - 1) string))
        # These attribute names do not adhere to nixpkgs' conventions. I'm
        # intentionally doing this so they match the names in my neovim config.
        (map (pluginName: nameValuePair pluginName (getPackage pluginName)))
        listToAttrs
        final.lib.recurseIntoAttrs
      ];

  patchedVimPlug = prev.vimPlugins.vim-plug.overrideAttrs (_old: {
    preInstall = ''
      # TODO: Workaround for this issue:
      # https://github.com/junegunn/vim-plug/issues/1135
      target="len(s:glob(s:rtp(a:plug), 'plugin'))"
      # First grep so the build will error out if the string isn't present
      grep -q "$target" plug.vim
      sed -ie "s@$target@v:true@" plug.vim

      # TODO: See if upstream can do this. If this is done and vim-plug is put in a
      # vim pack, then it loads automatically.
      autoload_path='autoload'
      mkdir "$autoload_path"
      mv plug.vim "$autoload_path/"
    '';
  });
in
{
  inherit myVimPlugins;
  vimPlugins = prev.vimPlugins // vimPluginsFromFlake // { vim-plug = patchedVimPlug; };
}
