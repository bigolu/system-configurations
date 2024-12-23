#!/usr/bin/env sh

main() {
  run_in_nix_shell_containing_direnv \
    direnv allow .
  run_in_nix_shell_containing_direnv \
    env DEV_SHELL='ci-default' direnv exec . "$@"
}

run_in_nix_shell_containing_direnv() {
  nix shell \
    --impure --expr 'import ./nix/packages.nix' \
    bash direnv \
    --command "$@"
}

main "$@"
