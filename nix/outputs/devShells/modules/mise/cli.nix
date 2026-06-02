{ pkgs, lib, ... }:
let
  mktemp = lib.getExe' pkgs.coreutils "mktemp";
in
{
  devshell.packages = with pkgs; [
    mise
    # For running file-based tasks
    cached-nix-shell
  ];

  devshell.startup.mise.text = ''
    trust_marker="$PRJ_DATA_DIR/mise-config-trusted"
    if [[ ! -e $trust_marker ]]; then
      mise trust --quiet
      echo >"$trust_marker"
    fi

    export NIX_SHEBANG_NIXPKGS="$PWD/nix/packages"

    # We include all dependencies for nix shebang scripts in the dev shell. And
    # since we make a GC root for the dev shell, we don't need GC roots for the
    # individual nix shebang scripts.
    if [[ ''${CI:-} == 'true' ]]; then
      export NIX_SHEBANG_GC_ROOTS_DIR="$(${mktemp} --directory)"
    fi
  '';
}
