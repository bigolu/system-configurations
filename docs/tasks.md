## `check`

Run jobs to find/fix issues in the current commit (HEAD).


- **Usage**: `check [job]…`

### Arguments

#### `[job]…`

Job to run. If none are passed then all of them will be run. The list of jobs is in `hk.pkl` under the `check` hook.

## `debug`

Start portable home in an empty environment


- **Usage**: `debug [-b --bundle]`

### Flags

#### `-b --bundle`

Use `nix bundle` (slower)

## `sync`

Run jobs to sync your environment with the code. For example, running database migrations whenever the schema changes.


- **Usage**: `sync [--ask] [-v --verbose] [job]…`

### Arguments

#### `[job]…`

Job to run. If none are passed then all of them will be run. The list of jobs is in `hk.pkl` under the `sync` hook.

### Flags

#### `--ask`

Show a diff of the current state and the new state, and ask for confirmation, before syncing. This is only supported by the `system` job.

#### `-v --verbose`

Show the logs for the sync job. This is only supported by the `system` job.
