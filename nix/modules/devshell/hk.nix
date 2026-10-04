{ pkgs, ... }: {
  devshell = {
    startup.hk.text = ''
      # lua-language-server doesn't support environment variables in the middle
      # of a string so we have to do it here.
      export LUA_LS_NVIM_RUNTIME="/etc/profiles/per-user/$USER/share/nvim/runtime"
      export LUA_LS_NVIM_PACK="/etc/profiles/per-user/$USER/share/nvim/site/pack/bigolu/start"
    '';

    packages = with pkgs; [
      hk
      # I run `pkl eval hk.pkl` to fetch any imports so pkl-lsp can reference them.
      pkl
      # TODO: This is required for hk's shell completion so nixpkgs should make it
      # a dependency.
      usage

      # For the sync hook and the git hooks that these programs create.
      git-auto-sync
      git-auto-check

      # For the check hook
      actionlint
      betterleaks
      deadnix
      editorconfig-checker
      lua-language-server
      nixfmt
      nixpkgs-lint-community
      nufmt
      pkl
      prettier
      renovate
      rumdl
      statix
      stylua
      tombi
    ];
  };
}
