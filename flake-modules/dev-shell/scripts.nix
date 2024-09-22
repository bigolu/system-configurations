{
  pkgs,
  self,
  lintersAndFixers,
}:
let
  inherit (pkgs) lib;

  dependenciesByName = rec {
    get-secrets = {
      inputs = with pkgs; [
        jq
        coreutils
        nix
      ];
      path = "${self}/scripts/get-secrets.bash";
    };
    init-nix-darwin = {
      inputs = with pkgs; [
        curl
        coreutils
        nix
      ];
      path = "${self}/scripts/init-nix-darwin.bash";
    };
    treefmt = {
      inputs = [
        pkgs.treefmt
        pkgs.moreutils
      ];
      path = "${self}/scripts/treefmt.bash";
    };
    code-generation-generate-neovim-plugin-list = {
      inputs = with pkgs; [
        ast-grep
        jq
        coreutils
        gnused
      ];
      path = "${self}/scripts/code-generation/generate-neovim-plugin-list.bash";
    };
    code-generation-generate-gomod2nix-lock = {
      inputs = with pkgs; [ nix ];
      path = "${self}/scripts/code-generation/generate-gomod2nix-lock.bash";
    };
    code-generation-generate-readme-table-of-contents = {
      inputs = with pkgs; [ doctoc ];
      path = "${self}/scripts/code-generation/generate-readme-table-of-contents.bash";
    };
    code-generation-go-mod-tidy = {
      inputs = with pkgs; [ go ];
      path = "${self}/scripts/code-generation/go-mod-tidy.bash";
    };
    test = {
      inputs = with pkgs; [
        findutils
        jq
        nix
      ];
      path = "${self}/scripts/test.bash";
    };
    ci-set-nix-direnv-hash = {
      inputs = with pkgs; [ direnv ];
      path = "${self}/scripts/ci/set-nix-direnv-hash.bash";
    };
    ci-auto-merge = {
      inputs = with pkgs; [ gh ];
      path = "${self}/scripts/ci/auto-merge.bash";
    };
    git-hooks-notify = {
      inputs =
        with pkgs;
        [
          coreutils
          gitMinimal
          gnugrep
        ]
        ++ lib.lists.optionals pkgs.stdenv.isDarwin [
          terminal-notifier
        ]
        ++ lib.lists.optionals pkgs.stdenv.isLinux [ libnotify ];
      path = "${self}/scripts/git-hooks/notify.bash";
    };
    qa-glob = {
      inputs = with pkgs; [ findutils ];
      path = "${self}/scripts/qa/glob.bash";
    };
    qa-qa = {
      inputs =
        with pkgs;
        [
          gitMinimal
          moreutils
          parallel
          coreutils
          yq-go
        ]
        ++ qa-glob.inputs
        ++ lintersAndFixers
        ++ code-generation-generate-gomod2nix-lock.inputs
        ++ code-generation-generate-neovim-plugin-list.inputs
        ++ code-generation-generate-readme-table-of-contents.inputs
        ++ code-generation-go-mod-tidy.inputs;
      path = "${self}/scripts/qa/qa.bash";
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
        "cannot:${pkgs.moreutils}/bin/chronic"
      ] ++ lib.lists.optionals pkgs.stdenv.isDarwin [
        "cannot:${pkgs.terminal-notifier}/bin/terminal-notifier"
      ] ++ lib.lists.optionals pkgs.stdenv.isLinux [
        "cannot:${pkgs.libnotify}/bin/notify-send"
      ];
      keep = {
        # Homebrew's installer says to use this so I don't want to change it
        "/bin/bash" = true;
        "\"$subcommand\"" = true;
      };
      fake = {
        external =
          [
            # I don't want to resolve it since it's unfree
            "bws"
            "bash"
          ]
          ++ lib.lists.optionals pkgs.stdenv.isLinux [ "terminal-notifier" ]
          ++ lib.lists.optionals pkgs.stdenv.isDarwin [ "notify-send" ];
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
