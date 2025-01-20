set shell := ["bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# To handle multiple arguments that have spaces:
# https://github.com/casey/just/issues/647#issuecomment-1404056424
set positional-arguments := true

set export

set quiet

[doc('''List all recipes. You can run this whenever you forget something.''')]
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
    just "$MANAGER" "$CONFIGURATION"

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
  nix run \
    --impure --expr 'import ./nix/flake-package-set.nix' \
    home-manager -- switch --flake ".#$NAME"
  ./dotfiles/firefox-developer-edition/set-default-browser.bash
  echo 'Consider syncing COSMIC settings by running `just sync-cosmic-to-system`'

[private]
[group('System Management')]
[no-exit-message]
nix-darwin NAME:
  ./scripts/init-nix-darwin.bash "$NAME"

[doc('''
    Create a bundle for the specified package (e.g. .#shell) using the
    bundler included in this repository. This runs periodically in CI when
    releasing a new version of the shell.
''')]
[group('Nix')]
[no-exit-message]
bundle PACKAGE:
  nix bundle --bundler ".#$PACKAGE"

[doc('''
    Run various checks on the code, automatically fixing issues if
    possible. These checks are split into the following jobs: format,
    check-lint, fix-lint, and generate. It runs on all files that differ between
    the current branch and the default branch, including untracked files. This
    is usually what you want since you can assume any files merged into the
    default branch have been checked. In case you forget to run it, it also runs
    during the git pre-push hook, where it only checks files in the commits that
    you are about to push.

    If you want to see what kind of checks are being run, they're defined in
    lefthook.yaml.

    Arguments:
        JOBS: Comma-Delimited list of jobs. If you don't specify any jobs,
                all of them will be run. Possible jobs are: generate, format,
                fix-lint, and check-lint.
                Example: `just check format,generate`
''')]
[group('Checks')]
[no-exit-message]
check JOBS='':
    # The first git command uses merge-base in case the current branch is behind the
    # default branch. The second git command prints untracked files
    { \
      git diff -z --diff-filter=d --name-only "$(git merge-base origin/HEAD HEAD)"; \
      git ls-files -z --others --exclude-standard; \
    } | lefthook run check --files-from-stdin --jobs "$JOBS"

[doc('''
    This is the same as the check recipe above, except that it runs on all files.
    You should run this if you make changes that affect how any of the JOBS
    work. For example, changing the configuration file for a linter.
''')]
[group('Checks')]
[no-exit-message]
check-all JOBS='':
    # The second git command prints untracked files
    { \
      git ls-files -z; \
      git ls-files -z --others --exclude-standard; \
    } | lefthook run check --files-from-stdin --jobs "$JOBS"

[doc('''
    Run various jobs to synchronize your environment with the state of the code.
    Run this anytime you incorporate someone else's changes. For example, after
    doing 'git pull' or checking out someone else's branch.

    The list of jobs is in lefthook.yaml.
''')]
[group('Syncing')]
[no-exit-message]
sync:
    # TODO: The sync job has 'follows' enabled so I need to execution_out or else
    # nothing will show. I should open an issue for allowing output to be configured
    # per job, the same way 'follows' is.
    #
    # TODO: According to the lefthook documentation, this variable should _extend_
    # the output values specified in the config file, but it seems to be overwriting
    # them instead. For now, I'm duplicating the values specified in my config here.
    # I should open an issue.
    LEFTHOOK_OUTPUT='execution_info,execution_out' lefthook run sync

[doc('''
    This is the same as the sync recipe above, except that it forces all jobs
    specified to run, regardless of what files have changed. If no jobs are
    provided, then all of them are run.

    The list of jobs is in lefthook.yaml.

    Arguments:
        JOBS: Comma-Delimited list of jobs.
               Example: `just sync-force direnv,dev-shell`
''')]
[group('Syncing')]
[no-exit-message]
force-sync JOBS='':
    # TODO: The sync job has 'follows' enabled so I need to execution_out or else
    # nothing will show. I should open an issue for allowing output to be configured
    # per job, the same way 'follows' is.
    #
    # TODO: According to the lefthook documentation, this variable should _extend_
    # the output values specified in the config file, but it seems to be overwriting
    # them instead. For now, I'm duplicating the values specified in my config here.
    # I should open an issue.
    LEFTHOOK_OUTPUT='execution_info,execution_out' lefthook run sync --force --jobs "$JOBS"

[group('Syncing')]
[no-exit-message]
sync-cosmic-to-system:
    ./dotfiles/cosmic/sync.bash system

[group('Syncing')]
[no-exit-message]
sync-cosmic-to-repo:
    ./dotfiles/cosmic/sync.bash repo

[group('Secrets')]
[no-exit-message]
get-secrets:
    doppler run \
        --mount "$(mktemp --dry-run --suffix '.env')" \
        --only-secrets GH_TOKEN \
        --only-secrets RENOVATE_TOKEN \
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
    nix build --impure --ignore-try  --debugger --print-out-paths  --no-link "$PACKAGE"

[doc('''
    Run a command in a direnv CI environment

    Arguments:
        DEV_SHELL: The CI dev shell to load
        COMMAND: The command to run
''')]
[group('Debugging')]
[no-exit-message]
debug-ci DEV_SHELL +COMMAND:
    # I'm changing the direnv's cache directory, normally .direnv, so nix-direnv's
    # cached dev shell doesn't get overwritten with the one built here.
    CI=true DEV_SHELL="$DEV_SHELL" direnv_layout_dir="$(mktemp --directory)" nix shell \
        --ignore-environment \
        --keep CI --keep DEV_SHELL --keep direnv_layout_dir --keep HOME \
        nixpkgs#direnv nixpkgs#coreutils nixpkgs#bashInteractive nixpkgs#nix \
        --command direnv exec "$PWD" "${@:2}"
