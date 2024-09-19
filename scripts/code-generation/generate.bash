# This script is modeled after treefmt, which only supports formatting code.
# TODO: Open an issue to see if they could add support for this.

set -o errexit
set -o nounset
set -o pipefail

print_with_nul() {
  printf '%s\0' "$@"
}

config_yq() {
  yq --input-format yaml "$@" <./scripts/code-generation/config.yaml
}

config_yq_get_list() {
  config_yq --nul-output "$@"
}

config_has_generator() {
  config_yq --exit-status '.generators | has("'"$1"'")' 1>/dev/null 2>&1
}

config_get_generator_names() {
  config_yq_get_list '.generators | keys[]'
}

config_get_generator_includes() {
  config_yq_get_list ".generators.$1.includes[]"
}

config_get_generator_excludes() {
  config_yq_get_list ".generators.$1.excludes[]"
}

config_get_generator_command() {
  config_yq ".generators.$1.command"
}

config_get_generator_options() {
  config_yq_get_list ".generators.$1.options[]"
}

config_get_generator_command_and_options() {
  readarray -d '' options < <(config_get_generator_options "$1")
  command="$(config_get_generator_command "$1")"
  print_with_nul "$command" "${options[@]}"
}

# generators
if [ "${1:-}" = '--generators' ]; then
  IFS=',' read -ra generators <<<"$2"
  set -- "${@:2}"
  set -- "${@:2}"

  # Ensure input generators exist
  invalid_generators=()
  for generator in "${generators[@]}"; do
    if ! config_has_generator "$generator"; then
      invalid_generators=("${invalid_generators[@]}" "$generator")
    fi
  done
  if [ ${#invalid_generators[@]} -gt 0 ]; then
    echo 'Error: The following generators do not exist:'
    printf '%s\n' "${invalid_generators[@]}"
    exit 1
  fi
else
  readarray -d '' generators < <(config_get_generator_names)
fi

function files {
  readarray -d '' inputs

  if [ ${#inputs[@]} -eq 0 ]; then
    git ls-files -z
  # TODO: Avoid hitting ARG_MAX: https://www.in-ulm.de/~mascheck/various/argmax/
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

# Run generators on files
command_file="$(mktemp)"
readarray -d '' global_excludes < <(config_get_global_excludes)
for generator in "${generators[@]}"; do
  readarray -d '' includes < <(config_get_generator_includes "$generator")
  readarray -d '' excludes < <(config_get_generator_excludes "$generator")
  readarray -d '' filtered_files \
    < <(files | bash glob.bash filter "${includes[@]}" | bash glob.bash filter --invert "${excludes[@]}" "${global_excludes[@]}")
  if [ ${#filtered_files[@]} -eq 0 ]; then
    continue
  fi

  readarray -d '' command_and_options \
    < <(config_get_generator_command_and_options "$generator")
  full_command=("${command_and_options[@]}")

  printf 'echo -e "\\nRunning "%q"..."; echo "%s"; %s\n' \
    "$generator" \
    "$(printf '=%.0s' {1..40})" \
    "$(printf '%q ' chronic "${full_command[@]}")" \
    >>"$command_file"
done

if [ "${VERBOSE:-}" = 1 ]; then
  parallel --verbose <"$command_file"
else
  parallel <"$command_file"
fi
