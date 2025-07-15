final: prev:
let
  inherit (final.lib)
    getExe
    getExe'
    ;
in
{
  makePortableShell = import ./make-portable-shell final prev;
  mkShellWrapper = final.callPackage ./mk-shell-wrapper.nix { };

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
        # TODO: nix-shell sets the temporary directory environment variables. This is
        # a problem because cached-nix-shell caches the environment variables set by
        # nix-shell so when I execute the shell again, the temporary directory will
        # not exist which will break any programs that try to access it. To get
        # around this, I use this script as my shebang interpreter and then I unset
        # the variables. I'm thinking that once nix development environments are no
        # longer made from build-debugging environments, this won't be an issue
        # anymore[1]. Otherwise, I should see if cached-nix-shell could allow users
        # to specify variables that shouldn't get cached.
        #
        # [1]: https://github.com/NixOS/nixpkgs/pull/330822
        unset TMPDIR TEMPDIR TMP TEMP

        # Make GC roots for script dependencies. This is useful for preventing script
        # dependencies from getting garbage collected in CI.
        #
        # TODO: Maybe comment here with this workaround:
        # https://github.com/xzfc/cached-nix-shell/issues/34
        if [[ -n "''${NIX_SHEBANG_GC_ROOTS_DIR:-}" ]]; then
          # This file is created after making the roots to avoid recreating them the
          # next time the script is run.
          completion_marker="$NIX_SHEBANG_GC_ROOTS_DIR/$(${basename} "''${out:?}")"

          if [[ ! -e "$completion_marker" ]]; then
            ${mkdir} --parents "$NIX_SHEBANG_GC_ROOTS_DIR"

            # It's easier to split a newline-delimited string than a space-delimited
            # one since herestring (<<<) adds a newline to the end of the string.
            #
            # Assert it's set so shellcheck doesn't report an error
            : "''${buildInputs:?}"
            readarray -t gc_roots_to_make <<<"''${buildInputs// /$'\n'}"

            gc_roots_to_make+=("''${stdenv:?}")

            # cached-nix-shell stores a symlink to the nix-shell derivation and will
            # invalidate its cache if the derivation doesn't exist so we need to make
            # a gc root for it. i tried to use `nix-store --query --deriver $out`,
            # but it didn't work since $out is not a valid store path.
            db="$NIX_STORE/../var/nix/db/db.sqlite"
            nix_shell_derivation_query="
              SELECT ValidPaths.path
              FROM ValidPaths
              INNER JOIN DerivationOutputs ON ValidPaths.id=DerivationOutputs.drv
              WHERE DerivationOutputs.path='$out'
            "
            gc_roots_to_make+=("$(${sqlite3} "$db" "$nix_shell_derivation_query")")

            for store_path in "''${gc_roots_to_make[@]}"; do
              nix build \
                --out-link "$NIX_SHEBANG_GC_ROOTS_DIR/$(${basename} "$store_path")" \
                "$store_path"
            done

            ${touch} "$completion_marker"
          fi
        fi

        exec ${getExe interpreter} "$@"
      '';
    };
}
