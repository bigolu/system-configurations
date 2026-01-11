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
              path = if rootPath ? eval then ''"${rootPath.eval}"'' else escapeShellArg rootPath.text;
              shellGcRoot = "${path}/shell-gc-root";
              shell = "${path}/shell";
            in
            ''
              new_shell="$(
                nix-store --query --referrers-closure ${placeholder "out"} |
                  ${tail} --lines 1
              )"

              # The path to the GC roots derivation is included here to make it part
              # of the dev shell closure: ${derivation}

              if [[ ! -e ${path} ]]; then
                ${mkdir} --parents ${path}
              fi

              ${optionalString devShellDiff ''
                # If a terminal and IDE run this at the same time, the diff will only
                # be printed by the process that updates the GC root. To ensure the
                # diff is shown in the terminal, we store a separate symlink to the
                # dev shell that's only updated if stdout is connected to a terminal.
                if [[ ! ${shell} -ef "$new_shell" && -t 1 ]]; then
                  if [[ -e ${shell} ]]; then
                    ${dixExe} "$(${realpath} ${shell})" "$new_shell"
                  fi
                  ${ln} --force --no-dereference --symbolic "$new_shell" ${shell}
                fi
              ''}

              if [[ ! ${shellGcRoot} -ef "$new_shell" ]]; then
                # If the dev shell was bundled with `nix bundle`, then we shouldn't
                # make the GC root. We use `nix-store --query --hash` to see if the
                # path we want to make a root for is a valid store path. If it isn't,
                # the shell was probably bundled. Instead of making a root, we make a
                # plain symlink. This way, subsequent checks to see if the root is up
                # to date will pass and we won't have to keep running the
                # `nix-store --query --hash` command below which will be slower than
                # the `[[ ... -ef ... ]]` conditional above.
                if
                  type -P nix-store >/dev/null &&
                    nix-store --query --hash "$new_shell" >/dev/null 2>&1
                then
                  nix-store --add-root ${shellGcRoot} --realise "$new_shell" >/dev/null
                else
                  ${ln} --force --no-dereference --symbolic "$new_shell" ${shellGcRoot}
                fi
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
