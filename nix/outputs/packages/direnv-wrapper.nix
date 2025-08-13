# A wrapper for direnv with the following extra features:
#   - Allows you to specify a file to load besides .envrc. There's an open issue for
#     this[1].
#   - Runs `direnv allow`. There's an open issue for this[2].
#
# Usage:
#   direnv-wrapper <path_to_envrc> <direnv_arguments>...
#
# [1]: https://github.com/direnv/direnv/issues/348
# [2]: https://github.com/direnv/direnv/issues/227

{ nixpkgs, name, ... }:
nixpkgs.callPackage (
  {
    writeShellApplication,
    direnv,
    bash,
    coreutils,
  }:
  writeShellApplication {
    inherit name;
    runtimeInputs = [
      direnv
      bash
      coreutils
    ];
    text = ''
      envrc="''${1:?}"
      direnv_args=("''${@:2}")

      function clean_up {
        if [[ ''${did_link_envrc:-} == 'true' ]]; then
          rm .envrc
        fi

        if [[ -e ''${backup:-} ]]; then
          mv "$backup" .envrc
        fi
      }
      trap clean_up EXIT

      if [[ -e .envrc ]]; then
        backup="$(mktemp --directory)/.envrc"
        mv .envrc "$backup"
        # This way, if the trap fails to restore it, users can do it themselves.
        echo "Backed up .envrc to $backup" >&2
      fi

      ln --symbolic "$envrc" .envrc
      did_link_envrc='true'

      direnv allow .
      direnv "''${direnv_args[@]}"
    '';
  }
) { }
