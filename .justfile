set shell := ["bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# Choose a task. Only includes tasks that don't take arguments.
default:
    @just --choose --unsorted

# Display a list of all tasks.
help:
    @just --list --justfile {{ justfile() }} --unsorted

# Reload direnv
reload-dev-environment:
    nix-direnv-reload

# Switch to a new generation
switch:
    hostctl-switch

# Update flake inputs and switch to a new generation
upgrade: cleanup pull && commit
    # We pull first because otherwise tools might try to perform upgrades that
    # have already been performed on another machine and just need to be pulled
    # in. And if upgrading a tool results in a file being changed,
    # (e.g. flake.lock) then pulling afterwards might cause a merge conflict.
    hostctl-upgrade

# Preview changes from switching
preview-switch:
    hostctl-preview-switch

# Preview changes from upgrading
preview-upgrade:
    hostctl-preview-upgrade

# Rerun the on change actions that run after a git merge or rebase
run-on-change-actions:
    bash ./.git-hook-assets/on-change.bash

# Run everything that would be run in CI
ci:
    nix develop --ignore-environment --keep BWS_ACCESS_TOKEN --keep HOME .# --command bash -- ./tests.bash

get-secrets:
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail

    project_dir="$PWD"

    temp="$(mktemp --directory)"
    trap 'rm -rf $temp' SIGINT SIGTERM ERR EXIT
    cd $temp

    if test -z "${BWS_ACCESS_TOKEN:-}"; then
        printf 'Enter the service account token (or just press enter to cancel):'
        read -rs token
        test -z "$token" && exit
        export BWS_ACCESS_TOKEN="$token"
    fi

    bws="$(NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#bws --command which -- bws)"
    PATH="$(dirname "$bws"):$PATH"

    declare -A secrets_to_fetch=(
        ['917561bd-57d8-4009-8155-b0f9016c89a2']="$project_dir/secrets/bws.txt"
        ['b2fe18ea-c96b-48e6-ae20-b0f90159d299']="$project_dir/secrets/github.txt"
        ['a45acbd3-45ac-43f1-96fd-b0f9015b6c2c']="$HOME/.cloudflared/a52a24f6-92ee-4dc5-b537-24bad84b7b1f.json"
    )
    declare -A secrets_to_commit
    for bws_id in "${!secrets_to_fetch[@]}"; do
        destination="${secrets_to_fetch[$bws_id]}"
        temp_filename="$(printf "$destination" | tr '/' '%')"
        printf "$(bws secret get "$bws_id" | jq --raw-output '.value')" > "$temp_filename"
        secrets_to_commit["$temp_filename"]="$destination"
    done

    # Writing secrets now to ensure we only write secrets if we succeed in
    # getting all of them
    for temp_filename in "${!secrets_to_commit[@]}"; do
        destination="${secrets_to_commit[$temp_filename]}"
        mkdir -p "$(dirname "$destination")"
        mv "$temp_filename" "$destination"
    done

gomod2nix:
    cd ./flake-modules/bundler/gozip && nix develop github:nix-community/gomod2nix --command gomod2nix generate

[private]
go-mod-tidy:
    cd ./flake-modules/bundler/gozip && go mod tidy

# Format, lint, and fix all source code
[private]
format:
    treefmt

# Same as format except all files will be formatted regardless of their

# modified-date
[private]
format-no-cache:
    treefmt --no-cache

# Install git hooks
[private]
install-git-hooks:
    lefthook install --force

# TODO: Automate this with rsyslog
[private]
cleanup:
    rm -f ~/.local/state/nvim/*.log
    rm -f ~/.local/state/nvim/undo/*

# I'm not able to upgrade the nix and cacert that come with the nix installation
# using `nix profile upgrade '.*'` so here I'm installing them from the nixpkgs

# flake and giving them priority.
[private]
base-packages:
    sudo --set-home --preserve-env=PATH env nix profile install nixpkgs#nix --priority 4
    sudo --set-home --preserve-env=PATH env nix profile install nixpkgs#cacert --priority 4

# home-manager can't run these since they require root privileges
[private]
linux-root-scripts:
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail

    ./dotfiles/nix/set-locale-variable.bash
    ./dotfiles/nix/nix-fix/install-nix-fix.bash
    ./dotfiles/nix/systemd-garbage-collection/install.bash
    ./dotfiles/smart_plug/linux/install.bash
    ./dotfiles/linux/set-keyboard-to-mac-mode.sh
    ./dotfiles/keyd/install.bash
    ./dotfiles/firefox-developer-edition/set-default-browser.sh

# Apply the first generation of a home-manager configuration.
[private]
init-home-manager host_name: install-git-hooks get-secrets base-packages && linux-root-scripts
    nix run .#nix -- run .#homeManager -- switch --flake .#{{ host_name }}

[private]
brew:
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail

    if [ -x /usr/local/bin/brew ]; then
        exit
    fi

    # Install brew. Taken from the brew site: https://brew.sh/
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apply the first generation of a nix-darwin configuration.
[private]
init-nix-darwin host_name: install-git-hooks get-secrets base-packages brew
    nix run .#nix -- run .#nixDarwin -- switch --flake .#{{ host_name }}

# Generate the Table of Contents in the README
[private]
generate-readme-table-of-contents:
    npm exec --yes --package=markdown-toc -- markdown-toc --bullets '-' -i README.md

# Generate a file with a list of all my neovim plugins
[private]
generate-neovim-plugin-list:
    #!/usr/bin/env bash
    set -euo pipefail

    readarray -t config_files < <(find ./dotfiles/neovim/lua -type f -name '*.lua')
    sg --lang lua --pattern 'Plug($ARG $$$)' --json=compact "${config_files[@]}" | jq --raw-output '.[].metaVariables.single.ARG.text' \
    | cut -d'/' -f2 | sed 's/.$//' | sort --ignore-case --dictionary-order --unique > ./dotfiles/neovim/plugin-names.txt

# Pull changes from git remote
[private]
pull:
    #!/usr/bin/env fish
    # return if there is nothing to pull
    chronic git fetch
    if test -z "$(git log HEAD..@{u} --oneline)"
        echo 'Nothing to do.'
        return
    end

    echo "$(echo 'Commits made since last pull:'\n; git log '..@{u}')" | less

    # if there are changes, warn the user in the prompt
    set status_output "$(git status --porcelain)"
    if test -n "$status_output"
        set warning "$(echo -s (set_color yellow) ' (WARNING: The working directory is not clean)' (set_color normal))"
    else
        set warning ''
    end
    read --prompt-str "Would you like to pull$warning? (y/n): " --nchars 1 response
    if test $response = 'y'
        git pull
    end

# Commit changes to git remote
[private]
commit:
    #!/usr/bin/env fish
    # check if there are changes to commit
    set status_output "$(git status --porcelain)"
    if test -n "$status_output"
        git status
        read --prompt-str "Do you want to commit the changes? (y/n): " --nchars 1 response
        if test $response = 'y'
            git add --all
            git commit --message 'chore: upgrade tools'
        end
    else
        echo 'Nothing to commit.'
    end
