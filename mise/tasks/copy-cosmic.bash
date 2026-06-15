#nix --interpreter bash --packages bash rsync
#USAGE arg "<destination>"
#USAGE complete "destination" descriptions=#true run=#"printf '%s\n' 'repo:Copy from system to repo' 'system:Copy from repo to system'"#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

repo='dotfiles/cosmic/'
system="$HOME/.config/cosmic/"

case "${usage_destination:?}" in
	'repo')
		source="$system"
		destination="$repo"
		;;
	'system')
		source="$repo"
		destination="$system"
		;;
	*)
		# It shouldn't ever reach this case
		exit 1
		;;
esac

rsync --recursive "$source" "$destination"
