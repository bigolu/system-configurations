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
      inherit (final) coreutils sqlite;
      basename = getExe' coreutils "basename";
      mkdir = getExe' coreutils "mkdir";
      touch = getExe' coreutils "touch";
      sqlite3 = getExe sqlite;
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

                # cached-nix-shell stores a symlink to the nix-shell derivation and
                # will invalidate its cache if the derivation doesn't exist so we
                # need to make a GC root for it. I tried to use `nix-store --query
                # --deriver $out`, but it didn't work since $out is not a valid store
                # path.
                db="$NIX_STORE/../var/nix/db/db.sqlite"
                query="
                  SELECT ValidPaths.path
                  FROM ValidPaths
                  INNER JOIN DerivationOutputs ON ValidPaths.id=DerivationOutputs.drv
                  WHERE DerivationOutputs.path='$out'
                "
                derivation="$(${sqlite3} "$db" "$query")"
                gc_roots_to_make+=("$derivation")

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
