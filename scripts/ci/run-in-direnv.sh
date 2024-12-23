#!/usr/bin/env sh

nix shell \
  --impure --expr 'import ./nix/packages.nix' \
  bash direnv \
  --command env DEV_SHELL='ci-default' direnv exec . "$@"
