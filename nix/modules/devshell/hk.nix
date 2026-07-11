{ pkgs, ... }: {
  devshell = {
    startup.hk.text = ''
      # TODO: There's a bug in the built-in pkl parser so I'm using the CLI: The
      # built-in parser adds a trailing newline to multi-line strings, but it
      # shouldn't[1].
      #
      # [1]: https://pkl-lang.org/main/current/language-reference/index.html#multiline-strings
      export HK_PKL_BACKEND='pkl'
    '';

    packages = with pkgs; [
      hk
      # - I run `pkl eval hk.pkl` to fetch any imports so pkl-lsp can reference them.
      # - Since I set the environment variable `HK_PKL_BACKEND`, `hk` will use
      #   this to parse `hk.pkl`, instead of using the pklr rust library.
      pkl
      # TODO: This is required for hk's shell completion so nixpkgs should make it
      # a dependency.
      usage
      # I use this for the `shell` option.
      bash

      # For the sync hook and the git hooks that these programs create.
      git-auto-sync
      git-auto-check

      # For the check hook
      actionlint
      betterleaks
      coreutils
      deadnix
      editorconfig-checker
      fish
      lua-language-server
      markdownlint-cli2
      nixfmt
      nixpkgs-lint-community
      pkl
      prettier
      # for renovate-config-validator
      renovate
      shellcheck
      shfmt
      statix
      stylua
      taplo
    ];
  };
}
