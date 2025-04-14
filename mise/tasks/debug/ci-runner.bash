#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter yq-go coreutils]"
#MISE description="Run CI workflows locally"
#USAGE long_about """
#USAGE   > WARNING: Nix builds may not work in a container due to this bug: \
#USAGE   https://github.com/NixOS/nix/issues/11295.
#USAGE """
#USAGE
#USAGE arg "<event>" help="The event that should trigger the workflow(s)"
#USAGE complete "event" run=#"""
#USAGE   yq --no-doc '.. | select(has("on")) | .on | keys | .[]' .github/workflows/*
#USAGE """#
#USAGE
#USAGE flag "-f --force_container" help="Use a container even if it could be run natively"
#USAGE
#USAGE flag "-w --workflow <workflow-file>" var=#true help="Workflow(s) to run."
#USAGE complete "workflow-file" run=#"""
#USAGE   printf '%s\n' .github/workflows/*
#USAGE """#
#USAGE
#USAGE flag "-j --job <job>" var=#true help="Job(s) to run."
#USAGE complete "job" run=#"""
#USAGE   yq --no-doc '.. | select(has("jobs")) | .jobs | keys | .[]' .github/workflows/*
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

eval "workflows=(${usage_workflow:-})"
workflow_flags=()
# shellcheck disable=2154
# `workflows` is defined in an `eval` statement above
for workflow in "${workflows[@]}"; do
  workflow_flags+=(--workflows "$workflow")
done

eval "jobs=(${usage_job:-})"
job_flags=()
# shellcheck disable=2154
# `jobs` is defined in an `eval` statement above
for job in "${jobs[@]}"; do
  job_flags+=(--job "$job")
done

self_hosted_flags=()
if [[ ${usage_force_container:-} != true ]]; then
  workflow_files=(.github/workflows/*)

  yq_output="$(
    {
      yq --no-doc '[.. | select(has("runs-on")) | .runs-on] | .[]' "${workflow_files[@]}"
      yq --no-doc '.. | select(has("os")) | .os | .[]' "${workflow_files[@]}"
    } |
      sort --unique
  )"
  readarray -t os_list <<<"$yq_output"

  # e.g. 'Linux x86_64'
  current_platform="$(uname -ms)"

  self_hosted_os_list=()
  for os in "${os_list[@]}"; do
    if [[ $current_platform == 'Linux x86_64' ]]; then
      pattern='ubuntu-*'
      if [[ $os =~ $pattern ]]; then
        self_hosted_os_list+=("$os")
      fi
    elif [[ $current_platform == 'Darwin x86_64' ]]; then
      pattern='macos-*'
      if [[ $os =~ $pattern ]]; then
        self_hosted_os_list+=("$os")
      fi
    fi
  done

  for os in "${self_hosted_os_list[@]}"; do
    self_hosted_flags+=(--platform "${os}=-self-hosted")
  done
fi

environment_variable_flags=(
  # So `act` can access its cache directory, config directory, etc.
  --var HOME="$(mktemp --directory)"
)

nix_shell_args=(
  --file nix/flake-package-set.nix nix act
  # Dependencies for actions. This is needed if we're self hosting, otherwise the
  # container will have them.
  nodejs coreutils bash

  --command act
  # TODO: Can remove this platform when this is resolved:
  # https://github.com/nektos/act/issues/2329
  --platform ubuntu-24.04=catthehacker/ubuntu:act-latest
  --reuse
  --artifact-server-path "$PWD/.direnv/act-artifacts"
  --env CI_DEBUG=true
  "${workflow_flags[@]}" "${job_flags[@]}" "${self_hosted_flags[@]}"
  "${usage_event:?}"
)

mise run debug:make-isolated-env "${environment_variable_flags[@]}" -- "${nix_shell_args[@]}"
