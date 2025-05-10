final: prev:
let
  inherit (final.lib) getExe;
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
        if
          [[ -n "''${NIX_SHEBANG_GC_ROOTS_DIR:-}" ]] &&
            [[ ! -e "''${NIX_SHEBANG_GC_ROOTS_DIR:?}/''${out:?}" ]]
        then
          if [[ ! -e "$NIX_SHEBANG_GC_ROOTS_DIR" ]]; then
            mkdir "$NIX_SHEBANG_GC_ROOTS_DIR"
          fi

          nix build \
            --out-link "''${NIX_SHEBANG_GC_ROOTS_DIR:?}/$(${final.coreutils}/bin/basename "''${stdenv:?}")" \
            "''${stdenv:?}"
          printf '%s' "''${buildInputs:?}" |
            {
              readarray -t -d ' ' script_dependency_store_paths
              for path in "''${script_dependency_store_paths[@]}"; do
                nix build \
                  --out-link "''${NIX_SHEBANG_GC_ROOTS_DIR:?}/$(${final.coreutils}/bin/basename "$path")" \
                  "$path"
              done
            }
        fi

        exec ${getExe interpreter} "$@"
      '';
    };
}
