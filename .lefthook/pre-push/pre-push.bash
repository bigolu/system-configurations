set -o errexit
set -o nounset
set -o pipefail

# Good explanation of the pre-push hook and some pitfalls:
# https://github.com/evilmartians/lefthook/issues/147

remote="$1"
while read -r local_ref _local_oid _remote_ref _remote_oid; do
  # source: https://stackoverflow.com/a/50056710
  #
  # TODO: I'd like to get the branch being pushed to, but I don't know how to
  # do that. That wouldn't always be available anyway since the remote may not
  # exist yet.
  default_branch_name="$(LC_ALL=C git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"
  default_branch="$remote/$default_branch_name"

  # Technically, there's no reason to check the common ancestor commit itself
  # since it has been merged to the default branch. However, getting the
  # child of that commit is tricky since there may not be a single, immediate
  # child that leads to the local ref. There could be two commits that later
  # merged and the local ref could be a descendant of that merge commit. Since
  # trufflehog only accepts one commit to lint from, we'll just choose the
  # ancestor.
  #
  #        common_ancestor
  #         /\           \
  #        /  \           \
  #       /    \      default_branch
  #      A      B
  #       \    /
  #         C
  #         |
  #         |
  #      local_ref
  common_ancestor="$(git merge-base "$default_branch" "$local_ref")"

  chronic trufflehog --fail --no-update git --since-commit "$common_ancestor" "file://$PWD"
done
