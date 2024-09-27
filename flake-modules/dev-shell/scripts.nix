# Script names should be the path relative to the scripts directory, with '/'
# replaced by '-'.
#
# I don't make the scripts into packages because then I'd have to wait for the
# devShell to rebuild to test any script changes.

{
  pkgs,
  root,
}:
let
  inherit (pkgs) lib;

  code-generation-generate-neovim-plugin-list = {
    dependencies = with pkgs; [
      ast-grep
      jq
      coreutils
      gnused
    ];
    path = "scripts/code-generation/generate-neovim-plugin-list.bash";
  };

  code-generation-generate-gomod2nix-lock = {
    dependencies = with pkgs; [ nix ];
    path = "scripts/code-generation/generate-gomod2nix-lock.bash";
  };

  get-secrets = {
    dependencies = with pkgs; [
      jq
      coreutils
      nix
    ];
    path = "scripts/get-secrets.bash";
  };

  init-nix-darwin = {
    dependencies = with pkgs; [
      curl
      coreutils
      nix
    ];
    path = "scripts/init-nix-darwin.bash";
  };

  test = {
    dependencies = with pkgs; [
      findutils
      jq
      nix
    ];
    path = "scripts/test.bash";
  };

  fail-if-files-change = {
    dependencies = with pkgs; [
      gitMinimal
    ];
    path = "scripts/fail-if-files-change.bash";
  };

  ci-set-nix-direnv-hash = {
    dependencies = with pkgs; [ direnv ];
    path = "scripts/ci/set-nix-direnv-hash.bash";
  };

  ci-auto-merge = {
    dependencies = with pkgs; [ gh ];
    path = "scripts/ci/auto-merge.bash";
  };

  git-hooks-notify = {
    dependencies =
      with pkgs;
      [
        coreutils
        gitMinimal
        gnugrep
      ]
      ++ lib.lists.optionals pkgs.stdenv.isDarwin [ terminal-notifier ]
      ++ lib.lists.optionals pkgs.stdenv.isLinux [ libnotify ];
    path = "scripts/git-hooks/notify.bash";
  };

  dependenciesByName = {
    inherit
      code-generation-generate-neovim-plugin-list
      code-generation-generate-gomod2nix-lock
      get-secrets
      init-nix-darwin
      test
      ci-set-nix-direnv-hash
      ci-auto-merge
      git-hooks-notify
      fail-if-files-change
      ;
  };

  allDependencies = lib.trivial.pipe dependenciesByName [
    builtins.attrValues
    (map (builtins.getAttr "dependencies"))
    builtins.concatLists
  ];

  validationPackage = pkgs.resholve.mkDerivation {
    pname = "script-validation-package";
    version = "no-version";

    src = lib.fileset.toSource {
      root = root + "/scripts";
      fileset = root + "/scripts";
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p "$out/scripts"
      cp --dereference --recursive "$src"/* "$out/scripts/"
    '';

    solutions = {
      default = {
        scripts = lib.attrsets.foldlAttrs (
          acc: _: script:
          acc ++ [ script.path ]
        ) [ ] dependenciesByName;

        interpreter = "${pkgs.bash}/bin/bash";
        inputs = allDependencies;

        execer =
          [
            "cannot:${pkgs.fd}/bin/fd"
            "cannot:${pkgs.lua-language-server}/bin/lua-language-server"
            "cannot:${pkgs.ast-grep}/bin/ast-grep"
            "cannot:${pkgs.gitMinimal}/bin/git"
            "cannot:${pkgs.markdownlint-cli2}/bin/markdownlint-cli2"
            "cannot:${pkgs.ltex-ls}/bin/ltex-cli"
            "cannot:${pkgs.ripgrep}/bin/rg"
            "cannot:${pkgs.reviewdog}/bin/reviewdog"
            "cannot:${pkgs.nix}/bin/nix"
            "cannot:${pkgs.direnv}/bin/direnv"
            "cannot:${pkgs.gh}/bin/gh"
          ]
          ++ lib.lists.optionals pkgs.stdenv.isDarwin [
            "cannot:${pkgs.terminal-notifier}/bin/terminal-notifier"
          ]
          ++ lib.lists.optionals pkgs.stdenv.isLinux [
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
      };
    };
  };
in
{
  inherit dependenciesByName validationPackage;
}
