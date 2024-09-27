set shell := ["bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# To handle multiple arguments that each could have spaces:
# https://github.com/casey/just/issues/647#issuecomment-1404056424
set positional-arguments := true

[doc('''List all tasks. You can run this whenever you forget something.''')]
list:
    @just --list --justfile {{ module_file() }} --unsorted --color always \
        | less -R '-PsPress q to quit, scroll up/down with the mouse or k/j'

[doc('''
    Upgrade the version of nix used by the system. This should be run every once
    in a while, like after flake updates.
''')]
[group('Host Management')]
upgrade-nix:
    sudo --set-home nix upgrade-nix --profile default

[doc('''
    Switch to a new generation of the host manager (nix-darwin or Home Manager)
    configuration.
''')]
[group('Host Management')]
switch:
    hostctl-switch

[doc('''
    Show a preview of what changes would be made to the host if you were to
    switch to a new configuration. This will not actually switch to the new
    configuration.
''')]
[group('Host Management')]
preview-switch:
    hostctl-preview-switch

[doc('''
    Apply the first generation of a Home Manager configuration. You only need to
    run this when you first clone the repository.

    Arguments:
        HOST_NAME: The name of the host configuration to apply.
''')]
[group('Host Management')]
init-home-manager HOST_NAME: sync-git-hooks get-secrets
    bash scripts/init-home-manager.bash "$@"

[doc('''
    Apply the first generation of a nix-darwin configuration. You only need to
    run this when you first clone the repository.

    Arguments:
        HOST_NAME: The name of the host configuration to apply.
''')]
[group('Host Management')]
init-nix-darwin HOST_NAME: sync-git-hooks get-secrets
    bash scripts/init-nix-darwin.bash "$@"
 
[doc('''
    Create a bundle for the specified package (e.g. .#shellMinimal) using the
    bundler included in this repository. This runs periodically in CI when
    releasing a new version of the shell.
''')]
[group('Nix')]
bundle PACKAGE:
  nix bundle --bundler .# "$1"

[doc('''
    This task runs the following tasks: format, check-lint, fix-lint, and all
    generator tasks. You should run this on any changed files before pushing. You
    can do so by running this task without arguments. In case you forget to run
    it, it also runs during the git pre-push hook.

    Arguments:
        FILES: The files to check. If none are given, then it runs on all files
               that differ from the default branch, including untracked files.
''')]
[group('Checks')]
check *FILES:
    # There's an extra '\0' at the end, but lefthook seems to be fine with that.
    [ $# -gt 0 ] \
      && printf '%s\0' "$@" \
      || bash scripts/get-files-that-differ-from-default-branch.bash \
    | lefthook run pre-push --files-from-stdin

[doc('''
    This task runs the following tasks on all files: format, check-lint,
    fix-lint, and all generator tasks. You should run this if you make changes
    to how any of the previously mentioned tasks work so those changes can be
    applied to all files.
''')]
[group('Checks')]
check-all:
    lefthook run pre-push --all-files

[doc('''
    Format the code. You should run this on any changed files before
    pushing. You can do so by running this task without arguments.

    Instead of running this directly, you can run 'check' which includes other checks.

    Arguments:
        FILES: The files to format. If none are given, then it runs on all files
               that differ from the default branch, including untracked files.

''')]
[group('Checks')]
format *FILES:
    # There's an extra '\0' at the end, but lefthook seems to be fine with that.
    [ $# -gt 0 ] \
      && printf '%s\0' "$@" \
      || bash scripts/get-files-that-differ-from-default-branch.bash \
    | lefthook run format --files-from-stdin

[doc('''
    Format all the code. You should run this if you make a change to how
    formatting is done (e.g. change the config file for a formatter) so the
    changes get applied to all files.

    Instead of running this directly, you can run 'check-all' which includes other checks.
''')]
[group('Checks')]
format-all:
    lefthook run format --all-files

[doc('''
    Check for lint issues. You should run this on any changed files before
    pushing. You can do so by running this task without arguments.

    Instead of running this directly, you can run 'check' which includes other checks.

    Arguments:
        FILES: The files to check. If none are given, then it runs on all files
               that differ from the default branch, including untracked files.
''')]
[group('Checks')]
check-lint *FILES:
    # There's an extra '\0' at the end, but lefthook seems to be fine with that.
    [ $# -gt 0 ] \
      && printf '%s\0' "$@" \
      || bash scripts/get-files-that-differ-from-default-branch.bash \
    | lefthook run check-lint --files-from-stdin

[doc('''
    Check for lint issues in all files. You should run this if you make a change to how
    lint checking is done (e.g. change the config file for a lint checker) so the
    changes get applied to all files.

    Instead of running this directly, you can run 'check-all' which includes other checks.
''')]
[group('Checks')]
check-lint-all:
    lefthook run check-lint --all-files

[doc('''
    Fix lint issues. You should run this on any changed files before
    pushing. You can do so by running this task without arguments.

    Instead of running this directly, you can run 'check' which includes other checks.

    Arguments:
        FILES: The files to fix. If none are given, then it runs on all files
               that differ from the default branch, including untracked files.
''')]
[group('Checks')]
fix-lint *FILES:
    # There's an extra '\0' at the end, but lefthook seems to be fine with that.
    [ $# -gt 0 ] \
      && printf '%s\0' "$@" \
      || bash scripts/get-files-that-differ-from-default-branch.bash \
    | lefthook run fix-lint --files-from-stdin

[doc('''
    Fix lint issues in all files. You should run this if you make a change to how
    lint fixing is done (e.g. change the config file for a lint fixer) so the
    changes get applied to all files.
    
    Instead of running this directly, you can run 'check-all' which includes other checks.
''')]
[group('Checks')]
fix-lint-all:
    lefthook run fix-lint --all-files

[doc('''
    Check for broken links in the input file(s). This runs periodically in CI so
    you shouldn't ever have to run this.

    Arguments:
        FILES: The files to check. These can be: files (e.g. `myfile.txt`), directories
               (e.g. `myDirectory`), remote files (e.g. `https://mysite.com/myfile.txt`),
               or a single `-` which will check any text from stdin.
''')]
[group('Checks')]
check-links *FILES:
    lychee "$@"

[doc('''
    Run the tests. Useful to run after a big change to ensure everything still
    works, but the cache workflow usually catches my mistakes so I don't run
    this much.
''')]
[group('Checks')]
test:
    bash scripts/test.bash

[doc('''
    Get all secrets from BitWarden Secrets Manager. You'll be prompted for
    a service token. You should run this whenever there are new secrets to
    fetch. This task will also reload the terminal's direnv environment. Don't
    forget to reload the direnv environment in your editor as well.
''')]
[group('Environment Management')]
get-secrets:
    bash scripts/get-secrets.bash
    direnv reload

[doc('''
    Synchronize nix-direnv with the Nix devShell and reload the direnv
    environment. nix-direnv is a direnv library that builds our Nix devShell and
    makes all the packages within it available on the $PATH. Since building the
    devShell can take a while, nix-direnv won't do it automatically. Instead,
    it will only build the devShell when it's explicitly told to do
    so, otherwise it just uses the last devShell it built. This task will tell
    nix-direnv to rebuild the devShell and reload the direnv environment.
    
    When to run this task:
      - After making changes to any of the files that affect the devShell
        so you can test your changes.
      - After anyone else makes changes to devShell-related files,
        this way you can apply the changes.

    Don't forget to reload the direnv environment in your editor as well.
''')]
[group('Environment Management')]
sync-nix-direnv:
    # TODO: watch_file isn't working
    touch flake.nix
    nix-direnv-reload

[doc('''
    Synchronize git hooks with the lefthook configuration. 

    When to run this task:
      - After making changes to any of the files that affect the lefthook
        configuration so you can test your changes.
      - After anyone else makes changes to lefthook-related files,
        this way you can apply the changes.
''')]
[group('Environment Management')]
sync-git-hooks:
    lefthook install --force

[doc('''
    Generate the lock file for gomod2nix. Run this after editing the go.mod. In
    case you forget, it runs during the pre-push hook.
''')]
[group('Code Generation')]
generate-gomod2nix-lock:
    lefthook run --force --commands gomod2nix-lock generate

[doc('''
    Generate a file with a list of all the neovim plugins. You shouldn't have to
    run this yourself since it runs during the pre-commit hook.
''')]
[group('Code Generation')]
generate-neovim-plugin-list:
    lefthook run --force --commands neovim-plugin-list generate

[doc('''
    Generate the Table of Contents in the README. Run it after editing the
    README. In case you forget, it runs during the pre-push hook.
''')]
[group('Code Generation')]
generate-readme-table-of-contents:
    lefthook run --force --commands readme-table-of-contents generate

[doc('''
    Regenerate a flake.lock for the flake.nix. This should be run after removing
    any inputs from the flake. You shouldn't have to run this manually since it
    runs on the pre-push hook.
''')]
[group('Code Generation')]
generate-flake-lock:
  nix flake lock .

[doc('''
    Sometimes a change is made that requires you to run something e.g.
    reinstalling dependencies when the dependencies file changes.  After a git
    checkout, rebase, or merge, you'll get a desktop notification with any
    actions you should take. It will also give you a task to run that can show
    you a diff of the changes, which is this task. Only run this if you want
    more details on any of the changes that you get notified about.
''')]
[group('Changes')]
show-changes NAME:
    [ -f .git/change-commands/"$1" ] \
      && bash .git/change-commands/"$1" \
      || echo 'No changes to show.'
