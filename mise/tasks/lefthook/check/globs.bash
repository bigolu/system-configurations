#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter ripgrep yq-go]"
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

# key: filename
# value: globs separated by a newline
declare -A globs_by_file

# GitHub Actions
shopt -s globstar
for file in .github/**/*.yaml; do
  quoted_globs="$(
    # If there are no matches, rg exits with 1, but i don't want the script to fail
    # in that case.
    set +o errexit
    rg --no-filename --only-matching 'hashFiles\((.*?)\)' --replace '$1' "$file" |
      # This one isn't actually a glob so filter it out
      rg --no-filename --invert-match '<pattern>' |
      rg ', *' --replace ' '
    set -o errexit
  )"
  eval "globs=($quoted_globs)"
  if ((${#globs[@]} > 0)); then
    IFS=$'\n' globs_by_file["$file"]="${globs[*]}"
  fi
done

file='lefthook.yaml'
globs_by_file["$file"]="$(
  yq '
    # Remove comments
    ... comments="" |
    # Recurse into sub maps
    .. |
    # These are the keys that contain globs
    select(has("glob") or has("exclude")) |
    # The values will either be strings or arrays so force them all to be arrays
    [.glob] + [.exclude] |
    flatten |
    .[]
  ' "$file"
)"

found_error=
for file in "${!globs_by_file[@]}"; do
  readarray -t globs <<<"${globs_by_file[$file]}"
  for glob in "${globs[@]}"; do
    if ! rg --quiet --max-count 1 --glob "$glob" '.*'; then
      echo -e "${red}[error] The following glob in '$file' no longer matches any files: ${glob}${reset}" >&2
      found_error='true'
    fi
  done
done
if [[ $found_error == 'true' ]]; then
  exit 1
fi
