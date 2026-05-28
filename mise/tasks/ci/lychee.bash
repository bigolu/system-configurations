#!
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter gh lychee coreutils git
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

issue_title='Link Checker Report'

function main {
	local report
	report="$(mktemp)"

	local lychee_exit_code
	lychee_exit_code="$(run_lychee "$report")"

	case "$lychee_exit_code" in
		# There are no broken links
		0)
			close_issue
			;;
		# There are broken links
		2)
			add_workflow_url "$report"
			open_issue "$report"
			;;
		*)
			exit "$lychee_exit_code"
			;;
	esac
}

function run_lychee {
	local -r report="$1"

	# Reserve stdout for printing lychee's exit code
	local stdout
	exec {stdout}>&1
	exec 1>&2

	git ls-files |
		{
			set +o errexit
			lychee --format markdown --output "$report" --files-from -
			echo $? 1>&"$stdout"
			set -o errexit
		}
}

function add_workflow_url {
	local -r report="$1"
	echo \
		"<footer><a href=\"${GITHUB_WORKFLOW_RUN_URL:-}\">Workflow run</a></footer>" \
		>>"$report"
}

function open_issue {
	local -r report="$1"

	local issue_number
	issue_number="$(find_issue)"
	if [[ -n $issue_number ]]; then
		gh issue edit --body-file "$report" "$issue_number"
	else
		gh issue create --title "$issue_title" --body-file "$report"
	fi
}

function close_issue {
	local issue_number
	issue_number="$(find_issue)"
	if [[ -n $issue_number ]]; then
		gh issue close "$issue_number" \
			--reason 'not planned' \
			--comment "This issue was closed by a [subsequent, successful workflow run](${GITHUB_WORKFLOW_RUN_URL:-})."
	fi
}

function find_issue {
	gh issue list \
		--json title,number \
		--jq ".[] | select(.title == \"$issue_title\") | .number"
}

function gh {
	if [[ ${CI:-} == 'true' ]]; then
		command gh "$@"
	else
		echo 'gh:' "$@" >&2
	fi
}

main "$@"
