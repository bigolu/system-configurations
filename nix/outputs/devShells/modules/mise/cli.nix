{ pkgs, ... }:
{
  packages = with pkgs; [
    mise
    # For running file-based tasks
    cached-nix-shell
  ];

  shellHook = ''
    # perf: We could just always run `mise trust --quiet`, but since we use direnv,
    # this would happen every time we load the environment and it's slower than
    # checking if a file exists.
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
