set -o errexit
set -o nounset
set -o pipefail

# On the first commit to a branch, there won't be a BEFORE commit. In this case,
# BEFORE will be a sha1 hash with all zeros.
null_hash="$(printf '0%.0s' {1..40})"

if [ "$EVENT_NAME" = 'push' ]; then
  COMMIT_LENGTH=$(printenv 'COMMITS' | jq 'length')
  if [ "$COMMIT_LENGTH" = '0' ]; then
    echo 'No commits to scan'
    exit
  fi

  if [ "$BEFORE" == "$null_hash" ]; then
    BASE="$(git rev-parse "$HEAD"'~'"$COMMIT_LENGTH")"
  else
    BASE="$BEFORE"
  fi

  HEAD="$AFTER"
elif [ "$EVENT_NAME" = 'pull_request' ]; then
  BASE="$BASE_SHA"
  HEAD="$HEAD_SHA"
fi

trufflehog \
  git "file://$PWD" \
  --since-commit "$BASE" \
  --branch "$HEAD" \
  --fail \
  --no-update \
  --github-actions
