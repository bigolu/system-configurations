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

red='\e[31m'
reset='\e[0m'

# GitHub Actions globs
quoted_globs="$(
  rg --no-filename --only-matching 'hashFiles\((.*?)\)' --replace '$1' .github |
    # This one isn't actually a glob so filter it out
    rg --no-filename --invert-match '<pattern>' |
    rg ', *' --replace ' '
)"
eval "globs=($quoted_globs)"
found_error=
# shellcheck disable=2154
# I assigned `globs` in the eval statement above
for glob in "${globs[@]}"; do
  if ! rg --quiet --max-count 1 --glob "$glob" '.*'; then
    echo -e "${red}[error] This glob no longer matches any files: ${glob}${reset}" >&2
    found_error='true'
  fi
done
if [[ $found_error == 'true' ]]; then
  exit 1
fi
