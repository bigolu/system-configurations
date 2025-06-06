## `bundle`

Create a bundle for the specified package using the bundler in this repository.


- **Usage**: `bundle <package>`

Create a bundle

### Arguments

#### `<package>`

The package to build e.g. .#shell

## `check`

Run jobs to find/fix issues with the code. It runs on all files that differ between the current branch and the default branch, and untracked files. This is usually what you want since you can assume any files merged into the default branch have no issues. You usually don't have to run this manually since it runs during the git pre-commit hook, where it only runs on staged files. The exception to this is when you make changes to how any of the jobs work, like modifying `lefthook.yaml` for example. In which case, you should run this with the `--all-files` flag which forces the jobs to run on all files, even unchanged ones. The list of jobs is in `lefthook.yaml`.


- **Usage**: `check [-a --all-files] [jobs]…`

Run jobs to find/fix issues

### Arguments

#### `[jobs]…`

Jobs to run. If none are passed then all of them will be run

### Flags

#### `-a --all-files`

Run on all files

## `copy-cosmic`

- **Usage**: `copy-cosmic <destination>`

### Arguments

#### `<destination>`

**Choices:**

- `to-repo`
- `to-system`

## `debug:build`

- **Usage**: `debug:build <flakeref>`

Run `nix build` in debug mode

### Arguments

#### `<flakeref>`

The flakeref of the derivation to build e.g. `.#shell`

## `debug:ci-direnv`

- **Usage**: `debug:ci-direnv <nix_dev_shell>`

Start a Bash shell in a direnv CI environment

### Arguments

#### `<nix_dev_shell>`

The dev shell that direnv should load

## `debug:shell`

- **Usage**: `debug:shell`

Start `.#shell` in an empty environment

## `get-secrets`

- **Usage**: `get-secrets`

## `help`

- **Usage**: `help`

Open this page

## `sync`

Run jobs to synchronize your environment with the code. For example, running database migrations whenever the schema changes. You shouldn't have to run this manually since a git hook is provided to automatically run this after `git pull` and `git checkout`. The list of jobs is in `lefthook.yaml`.


- **Usage**: `sync [jobs]…`

Synchronize your environment with the code

### Arguments

#### `[jobs]…`

Jobs to run. If none are passed then all of them will be run

## `system:preview-sync`

Show a preview of what changes would be made to the system if you applied the current configuration.


- **Usage**: `system:preview-sync`

Preview system config application
