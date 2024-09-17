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

rg() {
  command rg --line-regexp --null-data --null "$@"
}

rg_make_regexp_flags() {
  flags=()
  for pattern in "$@"; do
    flags=("${flags[@]}" '--regexp' "$pattern")
  done

  print_with_nul "${flags[@]}"
}

config_yq() {
  yq --input-format yaml "$@" <./scripts/lint/lint.yaml
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

# Files
if [ $# -eq 0 ]; then
  readarray -d '' files < <(git ls-files -z)
else
  # Ensure input files exist
  nonexistent_files=()
  for file in "$@"; do
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
  readarray -d '' files \
    < <(realpath --zero --canonicalize-existing --no-symlinks --relative-to "$PWD" "$@")
fi

# Filter out files that match the global excludes
readarray -d '' global_excludes < <(config_get_global_excludes)
readarray -d '' rg_exclude_flags \
  < <(rg_make_regexp_flags "${global_excludes[@]}")
readarray -d '' files \
  < <(print_with_nul "${files[@]}" | rg --invert-match "${rg_exclude_flags[@]}")

if [ ${#files[@]} -eq 0 ]; then
  exit
fi

# Run linters on files
command_file="$(mktemp)"
for linter in "${linters[@]}"; do
  readarray -d '' includes < <(config_get_linter_includes "$linter")
  readarray -d '' include_flags < <(rg_make_regexp_flags "${includes[@]}")
  readarray -d '' excludes < <(config_get_linter_excludes "$linter")
  readarray -d '' exclude_flags < <(rg_make_regexp_flags "${excludes[@]}")
  readarray -d '' filtered_files \
    < <(print_with_nul "${files[@]}" | rg "${include_flags[@]}" | rg --invert-match "${exclude_flags[@]}")
  if [ ${#filtered_files[@]} -eq 0 ]; then
    continue
  fi

  readarray -d '' command_and_options \
    < <(config_get_linter_command_and_options "$linter")
  full_command=("${command_and_options[@]}" "${filtered_files[@]}")

  printf 'echo -e "\\nRunning "%q"..."; echo "%s"; %s\n' \
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
