#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter renovate git go
#MISE hide=true

# Regarding the nix shell dependencies above:
#   - git is needed by Renovate
#   - go is needed for the values "gomodTidy" and "gomodUpdateImportPaths" of the
#     Renovate config setting "postUpdateOptions".

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

export RENOVATE_CONFIG_FILE="$PWD/renovate/global/config.json5"

# If a CI run fails, we'll have all the debug information without
# having to rerun it.
export LOG_LEVEL='debug'

if [[ ''${CI:-} != 'true' ]]; then
  export RENOVATE_DRY_RUN='full'
fi

# I want to run scripts from this repository in Renovate's `postUpgradeTasks`.
# Since `postUpgradeTasks` are executed in the directory of the repo that's
# currently being processed, I'll save the path to this repository's scripts.
export RENOVATE_BOT_SCRIPT_DIRECTORY="$PWD/renovate/global/scripts"

renovate
