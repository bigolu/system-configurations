#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils gawk chase
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# This way, we won't cache the user environment which is unnecessary since the
# installer action will recreate it.
rm -rf ~/.local/state/nix/profiles/profile-*

old="$HOME/.cache/gc-roots"

new="$(mktemp)"
{
  # We only want extant symlink destinations to be printed, but we don't want
  # realpath to exit with a non-zero code if it encounters a broken symlink since
  # that would cause the script to exit.
  set +o errexit
  realpath --quiet --canonicalize-existing /nix/var/nix/gcroots/auto/*
  set -o errexit
} |
  # Why we sort:
  #   - `comm`, used below, requires input files to be sorted
  #   - So we can compare `$old` to `$new` below
  #   - To deduplicate, which we do by using the `--unique` flag to `sort`
  sort --unique >"$new"

if [[ -e $old && $(<"$old") == $(<"$new") ]]; then
  echo 'should-save=false' >>"${GITHUB_OUTPUT:?}"
  exit
else
  echo 'should-save=true' >>"$GITHUB_OUTPUT"
fi

if [[ -e $old ]]; then
  echo '::group::GC roots diff'
  echo 'Added roots:'
  comm --nocheck-order -13 "$old" "$new"
  echo
  echo 'Removed roots:'
  comm --nocheck-order -23 "$old" "$new"
  echo '::endgroup::'
else
  echo 'Old cache did not exist'
fi
echo '::group::All new roots'
cat "$new"
echo '::endgroup::'

# Run garbage collection to stop the nix store from growing indefinitely. This can
# happen because on a cache miss, we restore from the most recently used cache entry
# so we have to avoid accumulating data from old cache entries over time.
echo '::group::Garbage collection logs'
nix-collect-garbage --delete-old
echo '::endgroup::'

# Delete these directories for the same reason as above.
#
# TODO: I don't want these directories to be cached, but they're added by default by
# cache-nix-action. I tried to remove them by adding `!<path>` the `paths` input, but
# it didn't work which I think is because of this issue[1]. On one of my workflows,
# these directories were ~200 MB so removing them should save a lot of space.
#
# [1]: https://github.com/actions/toolkit/issues/713
sudo rm -rf ~root/.cache/nix
# If `fetchTree` is used and nix doesn't find a valid cache entry in `fetcher-cache`
# it will refetch the content. To avoid that we keep the `fetcher-cache`. For
# example, `nix flake archive` uses `fetchTree`.
paths_to_delete=()
for path in ~/.cache/nix/*; do
  if [[ ! $path =~ fetcher-cache* ]]; then
    paths_to_delete+=("$path")
  fi
done
rm -rf "${paths_to_delete[@]}"

cp "$new" "$old"
