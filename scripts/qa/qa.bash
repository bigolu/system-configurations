# This script is modeled after treefmt: https://github.com/numtide/treefmt
#
# treefmt only supports formatting code, but the authors are considering adding
# support for linting as well. https://github.com/numtide/treefmt/issues/11
#
# TODO: Open an issue to see if they could add support for code generation as
# well.

# Usage:
#
# bash qa.bash generate --list
# bash qa.bash generate [--generators [GENERATORS...]] [FILES...]
#
# bash qa.bash lint {check,fix} --list
# bash qa.bash lint {check,fix} [--linters [LINTERS...]] [FILES...]
#
# You can also pass FILES through stdin, NUL-delimited.
# GENERATORS and LINTERS should be delimited by ','.

set -o errexit
set -o nounset
set -o pipefail

# It's annoying to pass "$@" around so I'll just use a global variable.
inputs=("$@")

function main {
  parse_arguments

  case "$arg_action" in
  generate)
    generate
    ;;
  lint)
    lint
    ;;
  *)
    echo 'Error: unknown subcommand' 1>&2
    exit 1
    ;;
  esac
}

# START GENERATOR FUNCTIONS {{{
function generate {
  if [ "${arg_list:-}" = 1 ]; then
    config_get_generator_names
    return
  fi

  if [ "${#arg_generators[@]}" -eq 0 ]; then
    readarray -d '' generators < <(config_get_generator_names)
  else
    generators=("${arg_generators[@]}")
  fi

  printf '\nRunning code generators...\n%s\n' "$(printf '=%.0s' {1..40})"
  readarray -d '' global_excludes < <(config_get_global_excludes)
  made_changes=
  for generator in "${generators[@]}"; do
    readarray -d '' includes < <(config_get_generator_includes "$generator")
    readarray -d '' excludes < <(config_get_generator_excludes "$generator")
    readarray -d '' filtered_files \
      < <(get_files | bash scripts/qa/glob.bash filter "${includes[@]}" | bash scripts/qa/glob.bash filter --invert "${excludes[@]}" "${global_excludes[@]}")
    if [ ${#filtered_files[@]} -eq 0 ]; then
      continue
    fi

    readarray -d '' command_and_options \
      < <(config_get_generator_command_and_options "$generator")
    full_command=("${command_and_options[@]}")

    printf '\nRunning code generator: %s...\n%s' "$generator" "$(printf '=%.0s' {1..40})"
    if ! run_generator chronic "${full_command[@]}"; then
      made_changes=1
    fi
  done

  if [ "$made_changes" = '1' ]; then
    echo 'Changes made'
    return 1
  else
    echo 'No changes made'
  fi
}

# Generator exits with 0 whether it changes anything or not. Instead lets exit
# with 1 if something changes, similar to how formatters and linters behave.
function run_generator {
  repository_state_before_running="$(git diff) $(git ls-files --others --exclude-standard)"
  "$@"
  repository_state_after_running="$(git diff) $(git ls-files --others --exclude-standard)"

  if [ "$repository_state_before_running" != "$repository_state_after_running" ]; then
    return 1
  else
    return 0
  fi
}
# END GENERATOR FUNCTIONS }}}

# START LINT FUNCTIONS {{{
function lint {
  case "$arg_lint_action" in
  check)
    lint_check
    ;;
  fix)
    lint_fix
    ;;
  *)
    exit 1
    ;;
  esac
}

function lint_check {
  type=checkers

  if [ "${arg_list:-}" = 1 ]; then
    config_get_linter_names "$type"
    return
  fi

  if [ "${#arg_linters[@]}" -eq 0 ]; then
    readarray -d '' lint_checkers < <(config_get_linter_names "$type")
  else
    lint_checkers=("${arg_lint_checkers[@]}")
  fi

  command_file="$(mktemp)"
  readarray -d '' global_excludes < <(config_get_global_excludes)
  for lint_checker in "${lint_checkers[@]}"; do
    readarray -d '' includes < <(config_get_linter_includes "$type" "$lint_checker")
    readarray -d '' excludes < <(config_get_linter_excludes "$type" "$lint_checker")
    readarray -d '' filtered_files \
      < <(get_files | bash scripts/qa/glob.bash filter "${includes[@]}" | bash scripts/qa/glob.bash filter --invert "${excludes[@]}" "${global_excludes[@]}")
    if [ ${#filtered_files[@]} -eq 0 ]; then
      continue
    fi

    readarray -d '' command_and_options \
      < <(config_get_linter_command_and_options "$type" "$lint_checker")
    full_command=("${command_and_options[@]}" "${filtered_files[@]}")

    printf 'echo -e "\\nRunning lint checker: "%q"..."; echo "%s"; %s\n' \
      "$lint_checker" \
      "$(printf '=%.0s' {1..40})" \
      "$(printf '%q ' chronic "${full_command[@]}")" \
      >>"$command_file"
  done

  printf '\nRunning lint checkers...\n%s\n' "$(printf '=%.0s' {1..40})"
  if ! [ -s "$command_file" ]; then
    echo 'No lints found'
  else
    if [ "${VERBOSE:-}" = 1 ]; then
      if parallel --verbose <"$command_file"; then
        echo 'No lints found'
      fi
    else
      if chronic parallel <"$command_file"; then
        echo 'No lints found'
      fi
    fi
  fi
}

function lint_fix {
  type=fixers

  if [ "${arg_list:-}" = 1 ]; then
    config_get_linter_names "$type"
    return
  fi

  if [ "${#arg_linters[@]}" -eq 0 ]; then
    readarray -d '' lint_fixers < <(config_get_linter_names "$type")
  else
    lint_fixers=("${arg_linters[@]}")
  fi

  printf '\nRunning lint fixers...\n%s\n' "$(printf '=%.0s' {1..40})"
  made_fixes=
  readarray -d '' global_excludes < <(config_get_global_excludes)
  for lint_fixer in "${lint_fixers[@]}"; do
    readarray -d '' includes < <(config_get_linter_includes "$type" "$lint_fixer")
    readarray -d '' excludes < <(config_get_linter_excludes "$type" "$lint_fixer")
    readarray -d '' filtered_files \
      < <(get_files | bash scripts/qa/glob.bash filter "${includes[@]}" | bash scripts/qa/glob.bash filter --invert "${excludes[@]}" "${global_excludes[@]}")
    if [ ${#filtered_files[@]} -eq 0 ]; then
      continue
    fi

    readarray -d '' command_and_options \
      < <(config_get_linter_command_and_options "$type" "$lint_fixer")
    full_command=("${command_and_options[@]}" "${filtered_files[@]}")

    printf '\nRunning lint fixer: %s...\n%s' "$lint_fixer" "$(printf '=%.0s' {1..40})"
    if ! chronic "${full_command[@]}"; then
      made_fixes=1
    fi
  done

  if [ "$made_fixes" = '1' ]; then
    echo 'Fixes made'
    return 1
  else
    echo 'No fixes made'
  fi
}
# END LINT FUNCTIONS }}}

# START ARGUMENT FUNCTIONS {{{
function parse_arguments {
  # stdin
  readarray -d '' arg_files
  if [ "${#arg_files[@]}" -gt 0 ] && [ "${arg_files[-1]}" = $'\0' ]; then
    unset 'arg_files[-1]'
  fi

  arg_action="${inputs[0]}"
  remove_arg

  if [ "$arg_action" = generate ]; then
    arg_generators=()

    if has_more_args; then
      if [ "${inputs[0]}" = '--list' ]; then
        arg_list=1
        return
      else # assume --generators
        remove_arg
        IFS=',' read -ra arg_generators <<<"${inputs[0]}"
        remove_arg
      fi
    fi
  else # asssume lint
    arg_lint_action="${inputs[0]}"
    remove_arg

    arg_linters=()

    if has_more_args; then
      if [ "${inputs[0]}" = '--list' ]; then
        arg_list=1
        return
      else # assume --linters
        remove_arg
        IFS=',' read -ra arg_linters <<<"${inputs[0]}"
        remove_arg
      fi
    fi
  fi

  # everything else must be files
  if has_more_args; then
    arg_files=("${inputs[@]}")
  fi
}

function has_more_args {
  if [ ${#inputs[@]} -gt 0 ]; then
    return 0
  else
    return 1
  fi
}

function get_files {
  if [ ${#arg_files[@]} -eq 0 ]; then
    git ls-files -z
  else
    # Ensure input files exist
    nonexistent_files=()
    for file in "${arg_files[@]}"; do
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
    realpath --zero --canonicalize-existing --no-symlinks --relative-to "$PWD" "${arg_files[@]}"
  fi
}

function remove_arg {
  inputs=("${inputs[@]:1}")
}
# END ARGUMENT FUNCTIONS }}}

# START CONFIG FUNCTIONS {{{
config_yq() {
  yq --input-format yaml "$@" <./scripts/qa/config.yaml
}

config_yq_get_list() {
  config_yq --nul-output "$@"
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

function config_get_linter_names {
  config_yq_get_list ".linters.$1 | keys[]"
}

config_get_linter_includes() {
  config_yq_get_list ".linters.$1.$2.includes[]"
}

config_get_linter_excludes() {
  config_yq_get_list ".linters.$1.$2.excludes[]"
}

config_get_linter_command() {
  config_yq ".linters.$1.$2.command"
}

config_get_linter_options() {
  config_yq_get_list ".linters.$1.$2.options[]"
}

config_get_linter_command_and_options() {
  readarray -d '' options < <(config_get_linter_options "$@")
  command="$(config_get_linter_command "$@")"
  print_with_nul "$command" "${options[@]}"
}

config_get_global_excludes() {
  config_yq_get_list '.global.excludes[]'
}
# END CONFIG FUNCTIONS }}}

# START UTILITY FUNCTIONS {{{
print_with_nul() {
  printf '%s\0' "$@"
}
# END UTILITY FUNCTIONS }}}

main
