# - You can perform filtering on your roots which would be hard to do with
#   nix-direnv. For example, filtering your npins' pins based on which platforms they
#   apply to. This way, a macOS only pin won't have a GC root on Linux.
# - The option to show a diff of your dev shell when it changes. This useful for
#   verifying that a refactor doesn't change the dev shell or just seeing what has
#   changed.
# - Roots are joined into a single derivation so you'll only have a single GC root
#   per project. This is reduces noise in the full list of GC roots for your system
#   (/nix/var/nix/gcroots/auto).

{
  lib,
  nixpkgs,
  ...
}:
nixpkgs.callPackage (
  {
    dix,
    coreutils,
    writeTextFile,
  }:
  let
    inherit (builtins) elem;
    inherit (lib)
      pipe
      escapeShellArg
      isStorePath
      attrsToList
      concatMap
      getExe
      mapAttrsToList
      optionalString
      genericClosure
      getExe'
      concatLines
      filter
      filterAttrs
      id
      ;

    handlers = {
      paths = id;

      # There's an issue for having flakes retain a reference to their inputs[1].
      #
      # [1]: https://github.com/NixOS/nix/issues/6895
      flake =
        let
          getInputsClosure =
            {
              inputs,
              # We take strings so we can determine if an input should be excluded
              # just by its name, i.e. the key in the `inputs` set. This way, we can
              # avoid fetching an excluded input and its transitive inputs. For this
              # same reason, we only allow direct inputs to be excluded.
              exclude ? [ ],
            }:
            let
              removeExcluded = filterAttrs (name: _input: !(elem name exclude));
              toClosureNodes = mapAttrsToList (
                # Used by `genericClosure` for equality checks
                _name: input: input // { key = input.outPath; }
              );
            in
            # There may be cycles if a user sets `inputs.foo.inputs.bar.follows = ""`
            # which would point bar to `self`. This is sometimes done to remove
            # unnecessary inputs like development-only inputs. `genericClosure` will
            # handle this case.
            genericClosure {
              startSet = pipe inputs [
                removeExcluded
                toClosureNodes
              ];
              # Non-Flake inputs will not have inputs
              operator = input: toClosureNodes (input.inputs or { });
            };
        in
        config:
        pipe config [
          getInputsClosure
          # If these inputs came from `lix/flake-compat` and `copySourceTreeToStore`
          # is false, then the outPath any direct inputs of type "path" will not be a
          # store path.
          (filter isStorePath)
        ];
    };

    makeDerivation =
      {
        roots,
        rootPath ? {
          text = "dev-shell-gc-root";
        },
        devShellDiff ? true,
      }:
      let
        derivation = writeTextFile {
          name = "roots.txt";
          text = concatLines roots;
          passthru.script =
            let
              dixExe = getExe dix;
              ln = getExe' coreutils "ln";
              realpath = getExe' coreutils "realpath";
              mkdir = getExe' coreutils "mkdir";
              tail = getExe' coreutils "tail";
              touch = getExe' coreutils "touch";
              mktemp = getExe' coreutils "mktemp";
              rm = getExe' coreutils "rm";
              mv = getExe' coreutils "mv";

              path = if rootPath ? eval then ''"${rootPath.eval}"'' else escapeShellArg rootPath.text;
              shellGcRoot = "${path}/shell-gc-root";
              shellToDiff = "${path}/shell-to-diff";
              shellStorePathPrefix = "${path}/shell-store-path";
            in
            ''
              # The path to the GC roots derivation is included here to make it part
              # of the dev shell closure: ${derivation}

              # If the dev shell was bundled using `nix bundle`, then are things
              # we can no longer assume:
              #   - The presence of the `nix-store` binary: The bundle may be
              #     run on a machine that doesn't have nix installed so we can't
              #     assume `nix-store` exists.
              #   - The validity of store paths: The store paths in the bundle
              #     may not exist in the user's nix store. So before using any
              #     store path in a `nix-store` command, we have to make sure it
              #     exists.
              if type -P nix-store >/dev/null; then
                has_nix_store=true
              else
                has_nix_store=false
              fi
              function has_store_paths {
                nix-store --query --hash "$@" >/dev/null 2>&1
              }

              if [[ ! -e ${path} ]]; then
                ${mkdir} --parents ${path}
              fi

              shell_store_path=${shellStorePathPrefix}"''${DEVSHELL_DIR//\//-}"
              if [[ -e "$shell_store_path" ]]; then
                new_shell="$(<"$shell_store_path")"
              else
                if [[ $has_nix_store == 'true' ]] && has_store_paths "$DEVSHELL_DIR"; then
                  # TODO: `$DEVSHELL_DIR` is not the top-level derivation for
                  # the dev shell. We use this command to find it. Ideally,
                  # devshell would set an environment variable that contains the
                  # path to the top-level derivation.
                  new_shell="$(
                    nix-store --query --referrers-closure "$DEVSHELL_DIR" |
                      ${tail} --lines 1
                  )"
                else
                  new_shell="$DEVSHELL_DIR"
                fi

                # PERF: Cache the shell store path
                #
                # Remove the old cached path.
                # Add `--force` to avoid race condition between multiple direnv instances
                ${rm} --force ${shellStorePathPrefix}*
                # Create the file this way for atomicity to avoid race condition
                # between multiple direnv instances
                temp="$(${mktemp})"
                echo "$new_shell" >"$temp"
                ${mv} --force "$temp" "$shell_store_path"
              fi

              ${optionalString devShellDiff ''
                # If a terminal and IDE run this at the same time, the diff will only
                # be printed by the process that updates the GC root. To ensure the
                # diff is shown in the terminal, we store a separate symlink to the
                # dev shell that's only updated if stdout is connected to a terminal.
                if [[ ( ! ${shellToDiff} -ef "$new_shell" ) && -t 1 ]]; then
                  if
                    [[ -e ${shellToDiff} ]] &&
                      [[ $has_nix_store == 'true' ]] &&
                      has_store_paths ${shellToDiff} "$new_shell"
                  then
                    ${dixExe} "$(${realpath} ${shellToDiff})" "$new_shell"
                  fi
                  ${ln} --force --no-dereference --symbolic "$new_shell" ${shellToDiff}
                fi
              ''}

              if [[ ! ${shellGcRoot} -ef "$new_shell" ]]; then
                if [[ $has_nix_store == 'true' ]] && has_store_paths "$new_shell"; then
                  nix-store --add-root ${shellGcRoot} --realise "$new_shell" >/dev/null
                else
                  # PERF: By doing this, subsequent checks to see if the GC root
                  # is up to date will pass and we won't have to keep calling
                  # the `has_store_paths` function above. We want to avoid
                  # calling that function since it shells out to `nix-store`
                  # which would be slow.
                  ${ln} --force --no-dereference --symbolic "$new_shell" ${shellGcRoot}
                fi
              else
                # Users of `nh`[1] can delete GC roots that haven't been
                # modified in a certain amount of time. To avoid deleting this
                # GC root, we'll update the modification time.
                #
                # [1]: https://github.com/nix-community/nh
                ${touch} --no-dereference ${shellGcRoot}
              fi
            '';
        };
      in
      derivation;
  in
  config:
  pipe (config.roots or { }) [
    attrsToList
    (concatMap ({ name, value }: handlers.${name} value))
    (roots: config.script // { inherit roots; })
    makeDerivation
  ]
) { }
