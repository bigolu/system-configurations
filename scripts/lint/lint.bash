# This script is modeled after treefmt. treefmt only supports formatting code,
# but the authors are considering adding support for linting as well. If they do
# then treefmt may be able to replace this script:
# https://github.com/numtide/treefmt/issues/11

set -o errexit
set -o nounset
set -o pipefail

print_with_nul() {
  printf '%s\0' "$@"
}

config_yq() {
  yq --input-format yaml "$@" <./scripts/lint/config.yaml
}

config_yq_get_list() {
  config_yq --nul-output "$@"
}

config_has_linter() {
  config_yq --exit-status '.linters | has("'"$1"'")' 1>/dev/null 2>&1
}

config_get_linter_names() {
  config_yq_get_list '.linters | keys[]'
}

config_get_linter_includes() {
  config_yq_get_list ".linters.$1.includes[]"
}

config_get_linter_excludes() {
  config_yq_get_list ".linters.$1.excludes[]"
}

config_get_linter_command() {
  config_yq ".linters.$1.command"
}

config_get_linter_options() {
  config_yq_get_list ".linters.$1.options[]"
}

config_get_linter_command_and_options() {
  readarray -d '' options < <(config_get_linter_options "$1")
  command="$(config_get_linter_command "$1")"
  print_with_nul "$command" "${options[@]}"
}

config_get_global_excludes() {
  config_yq_get_list '.global.excludes[]'
}

# Linters
if [ "${1:-}" = '--linters' ]; then
  IFS=',' read -ra linters <<<"$2"
  set -- "${@:2}"
  set -- "${@:2}"

  # Ensure input linters exist
  invalid_linters=()
  for linter in "${linters[@]}"; do
    if ! config_has_linter "$linter"; then
      invalid_linters=("${invalid_linters[@]}" "$linter")
    fi
  done
  if [ ${#invalid_linters[@]} -gt 0 ]; then
    echo 'Error: The following linters do not exist:'
    printf '%s\n' "${invalid_linters[@]}"
    exit 1
  fi
else
  readarray -d '' linters < <(config_get_linter_names)
fi

readarray -d '' inputs
if [ "${inputs[-1]}" = $'\0' ]; then
  unset 'inputs[-1]'
fi
function files {
  if [ ${#inputs[@]} -eq 0 ]; then
    git ls-files -z
  else
    # Ensure input files exist
    nonexistent_files=()
    for file in "${inputs[@]}"; do
      if [ ! -f "$file" ]; then
        nonexistent_files=("${nonexistent_files[@]}" "$file")
      fi
    done
    if [ ${#nonexistent_files[@]} -gt 0 ]; then
      echo 'Error: The following files do not exist:'
      printf '%s\n' "${nonexistent_files[@]}"
      exit 1
    fi

    # Normalize the file names
    realpath --zero --canonicalize-existing --no-symlinks --relative-to "$PWD" "${inputs[@]}"
  fi
}

# Run linters on files
command_file="$(mktemp)"
readarray -d '' global_excludes < <(config_get_global_excludes)
for linter in "${linters[@]}"; do
  readarray -d '' includes < <(config_get_linter_includes "$linter")
  readarray -d '' excludes < <(config_get_linter_excludes "$linter")
  readarray -d '' filtered_files \
    < <(files | bash scripts/glob.bash filter "${includes[@]}" | bash scripts/glob.bash filter --invert "${excludes[@]}" "${global_excludes[@]}")
  if [ ${#filtered_files[@]} -eq 0 ]; then
    continue
  fi

  readarray -d '' command_and_options \
    < <(config_get_linter_command_and_options "$linter")
  full_command=("${command_and_options[@]}" "${filtered_files[@]}")

  printf 'echo -e "\\nRunning linter: "%q"..."; echo "%s"; %s\n' \
    "$linter" \
    "$(printf '=%.0s' {1..40})" \
    "$(printf '%q ' chronic "${full_command[@]}")" \
    >>"$command_file"
done

if [ "${VERBOSE:-}" = 1 ]; then
  parallel --verbose <"$command_file"
else
  parallel <"$command_file"
fi
