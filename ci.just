set shell := ["bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# To handle multiple arguments that each could have spaces:
# https://github.com/casey/just/issues/647#issuecomment-1404056424
set positional-arguments := true

[doc('''
    List all tasks. You can run this whenever you forget something.
''')]
list:
    @just --list --justfile {{ module_file() }} --unsorted --color always \
        | less -R '-PsPress q to quit, scroll up/down with the mouse or k/j'

fixup-renovate-pull-request-for-envrc:
    #!/usr/bin/env fish
    set original_envrc "$(cat .envrc)"
    set nix_direnv_url (string match --groups-only --regex --all -- 'source_url [\'"](?<url>https://raw.githubusercontent.com/nix-community/nix-direnv/.*/direnvrc.*)[\'"] [\'"].*[\'"]' "$original_envrc")
    set nix_direnv_hash (direnv fetchurl "$nix_direnv_url")
    set new_envrc "$(string replace --regex -- 'source_url [\'"](?<url>https://raw.githubusercontent.com/nix-community/nix-direnv/.*/direnvrc.*)[\'"] [\'"].*[\'"]' "source_url '$nix_direnv_url' '$nix_direnv_hash'" "$original_envrc")"
    echo "$new_envrc" > .envrc

check-lint REPORTER:
  bash scripts/ci/check-lint.bash "$@"

check-code-generation:
  bash scripts/ci/check-code-generation.bash