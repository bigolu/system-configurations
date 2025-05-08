#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter ripgrep]"
#MISE hide=true

# Sometimes after moving files around in the repository, globs need to be updated,
# but it's easy to forget to update them. This check helps with that by verifying
# that all globs match at least one file.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# GitHub Actions globs
quoted_globs="$(
  rg --no-filename --only-matching 'hashFiles\((.*?)\)' --replace '$1' .github |
    # This one isn't actually a glob so filter it out
    rg --no-filename --invert-match '<pattern>' |
    rg ', *' --replace ' '
)"
eval "globs=($quoted_globs)"
# Since GitHub Action evaluates globs from the parent directory of the repository
cd ..
# shellcheck disable=2154
# I assigned `globs` in the eval statement above
for glob in "${globs[@]}"; do
  rg --quiet --max-count 1 --glob "$glob" '.*'
done
