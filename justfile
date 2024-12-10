set shell := ["bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# To handle multiple arguments that each could have spaces:
# https://github.com/casey/just/issues/647#issuecomment-1404056424
set positional-arguments := true

set quiet

[doc('''List all tasks. You can run this whenever you forget something.''')]
[no-exit-message]
list:
    @just --list --justfile {{ module_file() }} --unsorted --color always \
        | "${PAGER:-cat}"

[doc('''
    Initialize a system. You only need to run this when you first clone the
    repository.

    Arguments:
        MANAGER: The name of the system manager to use.
        CONFIGURATION: The name of the configuration to apply.
''')]
[group('System Management')]
[no-exit-message]
initialize MANAGER CONFIGURATION: && force-sync
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail

    if [[ "$1" = 'home-manager' ]]; then
      just home-manager "$2"
    elif [[ "$1" = 'nix-darwin' ]]; then
      just nix-darwin "$2"
    else
      echo "Unknown system manager: $1" >&2
      exit 1
    fi

[doc('''
    Pull changes and apply them. You'll get notifications occasionally if there are
    changes so no need to run manually.
''')]
[group('System Management')]
[no-exit-message]
pull:
    system-config-pull

[doc('''
    Show a preview of what changes would be made to the system if you were to
    apply with the configuration.
''')]
[group('System Management')]
[no-exit-message]
preview:
    system-config-preview

[private]
[group('System Management')]
[no-exit-message]
home-manager NAME:
  nix run .#homeManager -- switch --flake .#"$1"
  ./dotfiles/firefox-developer-edition/set-default-browser.bash
  echo 'Consider syncing COSMIC settings by running `just cosmic-sync system`'

[private]
[group('System Management')]
[no-exit-message]
nix-darwin NAME:
  ./scripts/init-nix-darwin.bash "$1"

[doc('''
    Create a bundle for the specified package (e.g. .#shell) using the
    bundler included in this repository. This runs periodically in CI when
    releasing a new version of the shell.
''')]
[group('Nix')]
[no-exit-message]
bundle PACKAGE:
  nix bundle --bundler .# "$1"

[doc('''
    Run various checks on the code, automatically fixing issues if
    possible. These checks are split into the following groups: format,
    check-lint, fix-lint, and generate. It runs on all files that differ between
    the current branch and the default branch, including untracked files. This
    is usually what you want since you can assume any files merged into the
    default branch have been checked. In case you forget to run it, it also runs
    during the git pre-push hook, where it only checks files in the commits that
    you are about to push.

    If you want to see what kind of checks are being run, they're defined in
    .lefthook.yml.

    Arguments:
        GROUPS: Comma-Delimited list of groups. If you don't specify any groups,
                all of them will be run. Possible groups are: generate, format,
                fix-lint, and check-lint.
                Example: `just check format,generate`
''')]
[group('Checks')]
[no-exit-message]
check GROUPS='':
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail

    lefthook_arguments=()
    if [[ -n "$1" ]]; then
      lefthook_arguments+=(--commands "$1")
    fi
    lefthook run check "${lefthook_arguments[@]}"

[doc('''
    This is the same as the check task above, except that it runs on all files.
    You should run this if you make changes that affect how any of the GROUPS
    work. For example, changing the configuration file for a linter.
''')]
[group('Checks')]
[no-exit-message]
check-all GROUPS='':
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail

    lefthook_arguments=(--files-from-stdin)
    if [[ -n "$1" ]]; then
      lefthook_arguments+=(--commands "$1")
    fi

    {
      git ls-files -z
      # untracked files
      git ls-files -z --others --exclude-standard
    } | lefthook run check "${lefthook_arguments[@]}"

[doc('''
    Run various tasks to synchronize your environment with the state of the code.
    Run this anytime you incorporate someone else's changes. For example, after
    doing 'git pull' or checking out someone else's branch.

    For a list of available tasks, see .lefthook.yml.
''')]
[group('Syncing')]
[no-exit-message]
sync:
    # TODO: According to the documentation, the values here should extend the values
    # specified in the configuration file, but it seems like only the values
    # here are being used. I should make a smaller test case and possibly open an
    # issue. For now, I'll duplicate the values from the config file in here.
    #
    # SYNC: LEFTHOOK_OUTPUT
    LEFTHOOK_OUTPUT='execution_out,execution_info' lefthook run sync

[doc('''
    This is the same as the sync recipe above, except that it forces all tasks
    specified to run, regardless of what files have changed. If no tasks are
    provided, then all of them are run.

    For a list of available tasks, see .lefthook.yml.

    Arguments:
        TASKS: Comma-Delimited list of tasks.
               Example: `just sync-force direnv,dev-shell`
''')]
[group('Syncing')]
[no-exit-message]
force-sync TASKS='':
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail

    lefthook_arguments=(--force)
    if [[ -n "$1" ]]; then
      lefthook_arguments+=(--commands "$1")
    fi

    # TODO: According to the documentation, the values here should extend the values
    # specified in the configuration file, but it seems like only the values
    # here are being used. I should make a smaller test case and possibly open an
    # issue. For now, I'll duplicate the values from the config file in here.
    #
    # SYNC: LEFTHOOK_OUTPUT
    LEFTHOOK_OUTPUT='execution_out,execution_info' \
      lefthook run sync "${lefthook_arguments[@]}"

[group('Syncing')]
[no-exit-message]
cosmic-sync DESTINATION:
    ./dotfiles/cosmic/sync.bash "$1"

[group('Secrets')]
[no-exit-message]
get-secrets:
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail

    doppler run \
        --mount "$(mktemp --dry-run --suffix '.env')" \
        --only-secrets GH_TOKEN \
        -- \
        bash -c 'cat "$DOPPLER_CLI_SECRETS_PATH" >secrets.env'

[doc('''
    Run `nix build` in debug mode.

    Arguments:
        PACKAGE: The package to build.
                 Example: just debug .#darwinConfigurations.bigmac.system
''')]
[group('Debugging')]
[no-exit-message]
debug PACKAGE:
    nix build --impure --ignore-try  --debugger --print-out-paths  --no-link "$1"
