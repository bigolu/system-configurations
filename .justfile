set shell := ["bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# To handle multiple arguments that each could have spaces:
# https://github.com/casey/just/issues/647#issuecomment-1404056424
set positional-arguments := true

# TODO: Multi-Line doc comments aren't work for modules. I should report this.
[doc("A module containing tasks that are only run during continuous integration (CI). To see the tasks run `just ci`.")]
mod ci

[doc('''List all tasks. You can run this whenever you forget something.''')]
list:
    @just --list --justfile {{ module_file() }} --unsorted --color always \
        | less -R '-PsPress q to quit, scroll up/down with the mouse or k/j'

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
init-home-manager HOST_NAME: sync-git-hooks get-secrets install-nix-from-flake && run-linux-root-scripts
    nix run .#nix -- run .#homeManager -- switch --flake .#{{ HOST_NAME }}

[doc('''
    Apply the first generation of a nix-darwin configuration. You only need to
    run this when you first clone the repository.

    Arguments:
        HOST_NAME: The name of the host configuration to apply.
''')]
[group('Host Management')]
init-nix-darwin HOST_NAME: sync-git-hooks get-secrets install-nix-from-flake install-homebrew
    nix run .#nix -- run .#nixDarwin -- switch --flake .#{{ HOST_NAME }}

[doc('''
    Run tests. You should run this before submitting changes to find potential
    bugs.
''')]
[group('Checks')]
test:
    bash tests.bash

[doc('''
    Format source code. You should run this on all files if you make a
    change to how formatting is done. You should also run this on any changed
    files before committing, but you don't have to worry about that since this
    task gets run during the git pre-commit hook.

    Arguments:
        FILES: The files to format. If none are given, then all files will be
               formatted.
''')]
[group('Checks')]
format *FILES:
    fish scripts/treefmt-wrapper.fish "$@"

[doc('''
    Lint source code. You should run this on all files if you make a
    change to how linting is done. You should also run this on any changed
    files before committing, but you don't have to worry about that since this
    task gets run during the git pre-commit hook.

    Arguments:
        FILES: The files to lint. If none are given, then all files will be
               linted.
''')]
[group('Checks')]
lint *FILES:
    bash scripts/lint/lint.bash "$@"

[doc('''
    Get all secrets from BitWarden Secrets Manager. You'll be prompted for
    a service token. You should run this whenever there are new secrets to
    fetch. This task will also reload the direnv environment. If you are using
    the VS Code configuration in this repository then its direnv environment
    will be reloaded as well.
''')]
[group('Environment Management')]
get-secrets:
    bash scripts/get-secrets.bash
    # This will trigger an environment reload in the terminal and VS Code
    touch .envrc

[doc('''
    Synchronize nix-direnv with the Nix devShell. nix-direnv is a direnv library
    that builds our Nix devShell and makes all the packages within it
    available on the $PATH. Since building the devShell can take a
    while, nix-direnv won't do it automatically. Instead, nix-direnv will only
    build the devShell when it's explicitly told to do so, otherwise it just
    uses the last devShell it built. This task will tell nix-direnv to
    rebuild the devShell and reload the direnv environment.

    When to run this task:
      - After making changes to any of the files that affect the devShell
        so you can test your changes.
      - After anyone else makes changes to devShell-related files,
        this way you can apply the changes. You shouldn't have to worry
        about this case since there are post-rewrite and post-merge git hooks
        that will run this task if necessary, just answer yes when prompted.
        These hooks run after operations like `git pull`, `git checkout`, etc.

    Running this task will only reload the direnv environment in the terminal
    that it's run in.  After running this task you should reload the direnv
    environment inside your editor as well. If you're using VS Code along with
    the extensions and settings included in the repository, you don't have to
    do anything. VS Code will automatically reload its direnv environment after
    this task runs.
''')]
[group('Environment Management')]
sync-nix-direnv:
    nix-direnv-reload

[doc('''
    Synchronize git hooks with the lefthook configuration. 

    When to run this task:
      - After making changes to any of the files that affect the lefthook
        configuration so you can test your changes.
      - After anyone else makes changes to lefthook-related files,
        this way you can apply the changes. You shouldn't have to worry
        about this case since there are post-rewrite and post-merge git hooks
        that will run this task if necessary, just answer yes when prompted.
        These hooks run after operations like `git pull`, `git checkout`, etc.
''')]
[group('Environment Management')]
sync-git-hooks:
    lefthook install --force

[doc('''
    Generate the lock file for gomod2nix. You shouldn't have to run this
    yourself since it runs during the pre-commit hook.
''')]
[group('Code Generation')]
generate-gomod2nix-lock:
    cd ./flake-modules/bundler/gozip \
        && nix develop .#gomod2nix --command gomod2nix generate

[doc('''
    Generate a file with a list of all the neovim plugins. You shouldn't have to
    run this yourself since it runs during the pre-commit hook.
''')]
[group('Code Generation')]
generate-neovim-plugin-list:
    bash scripts/generate-neovim-plugin-list.bash

[doc('''
    Generate the Table of Contents in the README. You shouldn't have to run this
    yourself since it runs during the pre-commit hook.
''')]
[group('Code Generation')]
generate-readme-table-of-contents:
    doctoc README.md --github

[doc('''
    Run `go mod tidy`. You shouldn't have to run this yourself since it runs
    during the pre-commit hook.
''')]
[group('Code Generation')]
go-mod-tidy:
    cd ./flake-modules/bundler/gozip && go mod tidy

[doc('''
    Update all packages and switch to a new generation of the host manager
    (nix-darwin or Home Manager) configuration. You shouldn't have to run
    this since packages get updated on the remote automatically and there's a
    daemon running locally that will check for updates and trigger a desktop
    notification to pull and apply the changes.
''')]
[group('Debugging')]
upgrade:
    hostctl-upgrade

[doc('''
    Re-Run the post-change hook. Sometimes after the repository
    changes, like after a `git pull` or `git checkout`, certain tasks need to
    run, like `sync-git-hooks`. To automate this, we use a git post-merge
    and post-rewrite hook to run tasks based on what files have changed. You
    shouldn't have to run this yourself since git will. However, if the hook
    fails for some reason you can use this to run it again.
''')]
[group('Debugging')]
run-post-change-hook:
    bash ./.git-hook-assets/on-change.bash

[private]
install-homebrew:
    bash scripts/install-homebrew.bash

# I'm not able to upgrade the nix and cacert that come with the nix installation
# using `nix profile upgrade '.*'` so here I'm installing them from the nixpkgs
# flake and giving them priority over the original ones.
[private]
install-nix-from-flake:
    sudo --set-home --preserve-env=PATH \
        env nix profile install nixpkgs#nix --priority 4
    sudo --set-home --preserve-env=PATH \
        env nix profile install nixpkgs#cacert --priority 4

# Home Manager can't run these since they require root privileges so I'll run
# them here.
[private]
run-linux-root-scripts:
    bash scripts/run-linux-root-scripts.bash
