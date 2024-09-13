set -o errexit
set -o nounset
set -o pipefail

# DEBUG:
# echo "DEBUG"
# gh pr list --json number,title,mergeable --repo "$GITHUB_REPOSITORY" --label automerge
# echo

while IFS= read -r pr_number; do
  echo "Processing PR #$pr_number"

  comment_body=
  if [[ "$(gh pr checks "$pr_number" --json bucket --jq '.[].bucket' --repo "$GITHUB_REPOSITORY" --required)" =~ 'fail' ]]; then
    echo 'Status checks failed'
    comment_body='A status check failed so auto-merging has been disabled.'
  elif [ "$(gh pr view "$pr_number" --json mergeable --jq '.mergeable' --repo "$GITHUB_REPOSITORY")" = CONFLICTING ]; then
    echo 'PR is conflicted'
    comment_body='This PR has a conflict with its base branch so auto-merging has been disabled.'
  fi

  if [ -n "$comment_body" ]; then
    old_title="$(gh pr view "$pr_number" --json title --jq '.title' --repo "$GITHUB_REPOSITORY")"
    gh pr edit "$pr_number" --repo "$GITHUB_REPOSITORY" \
      --remove-label automerge \
      --add-label automerge-failed \
      --title "[automerge-failed] $old_title"
    gh pr comment "$pr_number" --repo "$GITHUB_REPOSITORY" \
      --body "$comment_body"
  else
    gh pr update-branch "$pr_number" --repo "$GITHUB_REPOSITORY" --rebase
    gh pr merge "$pr_number" --repo "$GITHUB_REPOSITORY" --auto --squash
  fi
done < <(gh pr list --json number --jq '.[].number' --repo "$GITHUB_REPOSITORY" --label automerge)
