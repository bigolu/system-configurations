final: prev:
let
  inherit (final.lib) getExe getExe';
  createMkShellWrapper = import ./create-mk-shell-wrapper.nix final prev;
in
{
  makePortableShell = import ./make-portable-shell final prev;

  mkShellWrapper = createMkShellWrapper prev.mkShell;
  mkShellWrapperNoCC = createMkShellWrapper prev.mkShellNoCC;

  makeNixShellInterpreterWithoutTmp =
    {
      name ? "nix-shell-interpreter",
      interpreter,
    }:
    let
      # I'm not adding these to `runtimeInputs` because I don't want them to be put
      # on the `PATH`.
      inherit (final) coreutils;
      basename = getExe' coreutils "basename";
      readlink = getExe' coreutils "readlink";
      mkdir = getExe' coreutils "mkdir";
      touch = getExe' coreutils "touch";
    in
    final.writeShellApplication {
      inherit name;
      runtimeInputs = [ interpreter ];
      text = ''
        # TODO: nix-shell sets the temporary directory environment variables.
        # This is a problem because cached-nix-shell caches the environment
        # variables set by nix-shell so when I execute the shell again, the
        # temporary directory will not exist which will break any programs that
        # try to access it. To get around this, I use this script as my shebang
        # interpreter and then I unset the variables. I'm thinking that once nix
        # development environments are no longer made from build-debugging
        # environments, this won't be an issue anymore[1]. Otherwise, I should
        # see if cached-nix-shell could allow users to specify variables that
        # shouldn't get cached.
        #
        # [1]: https://github.com/NixOS/nixpkgs/pull/330822
        unset TMPDIR TEMPDIR TMP TEMP

        # Make GC roots for script dependencies. This is useful for preventing script
        # dependencies from getting garbage collected in CI.
        #
        # TODO: Maybe comment here with this workaround:
        # https://github.com/xzfc/cached-nix-shell/issues/34
        if [[ -n "''${NIX_SHEBANG_GC_ROOTS_DIR:-}" ]]; then
          # I create this file after making the roots so I know not to do it again the
          # next time the script is run.
          completion_marker="$NIX_SHEBANG_GC_ROOTS_DIR/$(${basename} "''${out:?}")"

          if [[ ! -e "$completion_marker" ]]; then
            ${mkdir} --parents "$NIX_SHEBANG_GC_ROOTS_DIR"

            # Normally, I'd use a herestring (<<<), but that adds a newline to the end
            # of the string and since I split the string on spaces, the last piece
            # would have a newline at the end.
            printf '%s' "''${buildInputs:?}" |
              {
                readarray -t -d ' ' gc_roots_to_make

                gc_roots_to_make+=("''${stdenv:?}")

                shopt -s nullglob
                # TODO: I only want the derivation for the nix shell of the currently
                # running shebang script, but the file name of the derivation is
                # derived from the flags specified in the shebang[1], which I can't
                # easily get from here. Instead, I just make GC roots for all
                # derivations.
                #
                # [1]: https://github.com/xzfc/cached-nix-shell/blob/62e282be819646e3cdcd458af3f222e8f09e62ca/src/main.rs#L456
                for drv_symlink in "''${XDG_CACHE_HOME:-$HOME/.cache}/cached-nix-shell"/*.drv; do
                  if [[ -e $drv_symlink ]]; then
                    gc_roots_to_make+=("$(${readlink} --canonicalize "$drv_symlink")")
                  fi
                done

                for store_path in "''${gc_roots_to_make[@]}"; do
                  nix build \
                    --out-link "$NIX_SHEBANG_GC_ROOTS_DIR/$(${basename} "$store_path")" \
                    "$store_path"
                done
              }

            ${touch} "$completion_marker"
          fi
        fi

        exec ${getExe interpreter} "$@"
      '';
    };
}
