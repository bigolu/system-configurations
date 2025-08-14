{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    mise
    # For running file-based tasks
    cached-nix-shell
  ];

  devshell.startup.mise.text = ''
    trust_marker="''${direnv_layout_dir:-.direnv}/mise-config-trusted"
    if [[ ! -e $trust_marker ]]; then
      mise trust --quiet
      touch "$trust_marker"
    fi

    export NIX_SHEBANG_NIXPKGS="$PWD/nix/packages"

    # I don't want to make GC roots when debugging CI because unlike actual CI,
    # where new virtual machines are created for each run, they'll just accumulate.
    if [[ ''${CI:-} == 'true' ]] && [[ ''${CI_DEBUG:-} != 'true' ]]; then
      export NIX_SHEBANG_GC_ROOTS_DIR="$(mktemp --directory)"
    fi
  '';
}
