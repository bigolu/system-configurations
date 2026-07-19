#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function format {
	numfmt --to=iec --suffix=B "$1"
}

workspace=~/.local/state/seedbox
# GiB
max_size=$((400 * 1024 * 1024 * 1024))

torrents_total_size=0
for torrent in "$workspace/data/qBittorrent/BT_backup"/*.torrent; do
	torrent_size="$(imdl torrent show --json "$torrent" | jq .content_size)"
	torrents_total_size=$((torrents_total_size + torrent_size))
done
if ((torrents_total_size > max_size)); then
	# shellcheck disable=2312
	echo "Total torrent size is too big: $(format "$torrents_total_size"). Max size: $(format "$max_size")" >&2
	exit 1
fi

# Fail-Safe in case qbittorrent moves the torrent directory
workspace_size=$(du -s -B1 "$workspace" | cut -f1)
if ((workspace_size > max_size)); then
	# shellcheck disable=2312
	echo "Workspace size is too big: $(format "$workspace_size"). Max size: $(format "$max_size")" >&2
	exit 1
fi

# Fail-Safe in case qbittorrent isn't automatically adding the torrents.
max_torrents=20
torrent_files=("$workspace/torrent-files"/*.torrent)
torrent_count=${#torrent_files[@]}
if [[ $torrent_count -gt $max_torrents ]]; then
	echo 'Max autobrr torrent count exceeded' >&2
	exit 1
fi
