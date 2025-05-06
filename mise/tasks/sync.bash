#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter]"
#MISE description="Synchronize your environment with the code"
#USAGE long_about """
#USAGE   Run jobs to synchronize your environment with the code. For example, \
#USAGE   running database migrations whenever the schema changes. Run this anytime \
#USAGE   you incorporate someone else's changes. For example, after running \
#USAGE   `git pull` or checking out someone else's branch. The jobs to run will be \
#USAGE   automatically determined based on what files changed since the last pull, \
#USAGE   checkout, etc.
#USAGE
#USAGE   You can also force one or more sync jobs to run by passing their names. If \
#USAGE   you pass the special name `all`, then all of the jobs will be forced to \
#USAGE   run. Use this when you're the one making the change or you have a problem \
#USAGE   with the regular syncing. The list of jobs is in `lefthook.yaml`.
#USAGE """
#USAGE
#USAGE arg "[forced_jobs]" var=#true help="Jobs to forcibly run"
#USAGE complete "forced_jobs" run=#"""
#USAGE   echo all
#USAGE   fish -c 'complete --do-complete "lefthook run sync --jobs "'
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  eval "forced_jobs=(${usage_forced_jobs:-})"

  lefthook_forced_job_args=()
  # shellcheck disable=2154
  # `forced_jobs` is defined in an `eval` statement above
  if ((${#forced_jobs[@]} > 0)); then
    lefthook_forced_job_args+=(--force)

    should_run_all="$(contains 'all' "${forced_jobs[@]}")"
    if [[ $should_run_all == 'false' ]]; then
      joined_jobs="$(printf '%s,' "${forced_jobs[@]}")"
      joined_jobs="${joined_jobs::-1}"

      lefthook_forced_job_args+=(--jobs "$joined_jobs")
    fi
  fi

  # TODO: For any job that has 'follows' enabled, 'execution_out' needs to be enabled
  # or else nothing will show. I have it off by default so this will enable it. I
  # should open an issue for allowing output to be configured per job, the same way
  # 'follows' is.
  #
  # TODO: According to the lefthook documentation, this variable should _extend_ the
  # output values specified in the config file, but it seems to be overwriting them
  # instead. For now, I'm duplicating the values specified in my config here. I should
  # open an issue.
  LEFTHOOK_OUTPUT='execution_info,execution_out' lefthook run sync "${lefthook_forced_job_args[@]}"
}

function contains {
  local -r target="${1:?}"
  local -ra list=("${@:2}")

  for item in "${list[@]}"; do
    if [[ $item == "$target" ]]; then
      echo 'true'
      return
    fi
  done

  echo 'false'
}

main
