{ pkgs, ... }:
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

    export CNS_NIXPKGS="$PRJ_ROOT/nix/packages.nix"

    # We include the dependencies for all nix shebang scripts in the development
    # devshell. Since we already make a GC root for the devshell, we don't need
    # GC roots for individual nix shebang scripts in a development devshell,
    # only CI.
    export CNS_GC_ROOT="''${CI:-}"
  '';
}
