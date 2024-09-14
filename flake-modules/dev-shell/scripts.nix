{
  pkgs,
  self,
  lintersAndFixers,
}:
let
  inherit (pkgs) lib;

  dependenciesByName = rec {
    fish-all = {
      inputs = with pkgs; [
        fish
        fd
      ];
      path = "${self}/scripts/fish-all.bash";
    };
    desktop-file-validate-all = {
      inputs = with pkgs; [
        fd
        desktop-file-utils
      ];
      path = "${self}/scripts/desktop-file-validate-all.bash";
    };
    generate-neovim-plugin-list = {
      inputs = with pkgs; [
        ast-grep
        jq
        coreutils
        gnused
      ];
      path = "${self}/scripts/generate-neovim-plugin-list.bash";
    };
    get-secrets = {
      inputs = with pkgs; [
        jq
        coreutils
        nix
      ];
      path = "${self}/scripts/get-secrets.bash";
    };
    install-homebrew = {
      inputs = with pkgs; [ curl ];
      path = "${self}/scripts/install-homebrew.bash";
    };
    ltex-cli-all = {
      inputs = with pkgs; [
        fd
        coreutils
        ltex-ls
      ];
      path = "${self}/scripts/ltex-cli-all.bash";
    };
    markdownlint-cli2-all = {
      inputs = with pkgs; [
        fd
        markdownlint-cli2
      ];
      path = "${self}/scripts/markdownlint-cli2-all.bash";
    };
    shellcheck-all = {
      inputs = with pkgs; [
        fd
        shellcheck
      ];
      path = "${self}/scripts/shellcheck-all.bash";
    };
    treefmt-wrapper = {
      inputs = with pkgs; [ treefmt ];
      path = "${self}/scripts/treefmt-wrapper.bash";
    };
    generate-gomod2nix-lock = {
      inputs = with pkgs; [ nix ];
      path = "${self}/scripts/generate-gomod2nix-lock.bash";
    };
    generate-readme-table-of-contents = {
      inputs = with pkgs; [ doctoc ];
      path = "${self}/scripts/generate-readme-table-of-contents.bash";
    };
    go-mod-tidy = {
      inputs = with pkgs; [ go ];
      path = "${self}/scripts/go-mod-tidy.bash";
    };
    test = {
      inputs = with pkgs; [
        findutils
        jq
        nix
      ];
      path = "${self}/scripts/test.bash";
    };
    lint = {
      inputs =
        with pkgs;
        [
          ripgrep
          yq-go
          coreutils
          gitMinimal
          parallel
        ]
        ++ lintersAndFixers;
      path = "${self}/scripts/lint/lint.bash";
    };
    ci-set-nix-direnv-hash = {
      inputs = with pkgs; [ direnv ];
      path = "${self}/scripts/ci/set-nix-direnv-hash.bash";
    };
    ci-auto-merge = {
      inputs = with pkgs; [ gh ];
      path = "${self}/scripts/ci/auto-merge.bash";
    };
    ci-lint = {
      inputs =
        with pkgs;
        [
          coreutils
          gitMinimal
          reviewdog
          treefmt
        ]
        ++ lintersAndFixers
        ++ shellcheck-all.inputs
        ++ markdownlint-cli2-all.inputs
        ++ ltex-cli-all.inputs
        ++ desktop-file-validate-all.inputs
        ++ fish-all.inputs;
      path = "${self}/scripts/ci/lint.bash";
    };
    ci-code-generation = {
      inputs =
        with pkgs;
        [ gitMinimal ]
        ++ generate-gomod2nix-lock.inputs
        ++ generate-neovim-plugin-list.inputs
        ++ generate-readme-table-of-contents.inputs
        ++ go-mod-tidy.inputs;
      path = "${self}/scripts/ci/check-code-generation.bash";
    };
  };

  allDependencies = lib.attrsets.foldlAttrs (
    accumulator: _: deps:
    accumulator ++ deps.inputs
  ) [ ] dependenciesByName;

  byName = lib.attrsets.mapAttrs (
    name: deps:
    pkgs.resholve.writeScriptBin name {
      interpreter = "${pkgs.bash}/bin/bash";
      inherit (deps) inputs;
      execer = [
        "cannot:${pkgs.fd}/bin/fd"
        "cannot:${pkgs.lua-language-server}/bin/lua-language-server"
        "cannot:${pkgs.ast-grep}/bin/ast-grep"
        "cannot:${pkgs.gitMinimal}/bin/git"
        "cannot:${pkgs.treefmt}/bin/treefmt"
        "cannot:${pkgs.markdownlint-cli2}/bin/markdownlint-cli2"
        "cannot:${pkgs.ltex-ls}/bin/ltex-cli"
        "cannot:${pkgs.ripgrep}/bin/rg"
        "cannot:${pkgs.reviewdog}/bin/reviewdog"
        "cannot:${pkgs.nix}/bin/nix"
        "cannot:${pkgs.yq-go}/bin/yq"
        "cannot:${pkgs.parallel}/bin/parallel"
        "cannot:${pkgs.direnv}/bin/direnv"
        "cannot:${pkgs.gh}/bin/gh"
        "cannot:${pkgs.go}/bin/go"
        "cannot:${pkgs.doctoc}/bin/doctoc"
      ];
      keep = {
        # Homebrew's installer says to use this so I don't want to change it
        "/bin/bash" = true;
      };
      fake = {
        # I don't want to resolve it since it's unfree
        external = [ "bws" ];
      };
    } (builtins.readFile deps.path)
  ) dependenciesByName;

  meta = pkgs.symlinkJoin {
    name = "tools";
    paths = builtins.attrValues byName;
  };
in
{
  inherit
    byName
    allDependencies
    dependenciesByName
    meta
    ;
}
