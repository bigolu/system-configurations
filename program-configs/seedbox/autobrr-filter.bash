#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

workspace=~/.local/state/seedbox

max_torrents=20
torrent_files=("$workspace/data/qBittorrent/BT_backup"/*.torrent)
torrent_count=${#torrent_files[@]}
if [[ $torrent_count -gt $max_torrents ]]; then
	echo 'Max torrent count exceeded' >&2
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

# Fail-Safe in case qbittorrent moves the torrent directory
#
# 200GB
max_size=$((200 * 1024 * 1024 * 1024))
size=$(du -s -B1 "$workspace" | cut -f1)
if ((size > max_size)); then
	function format {
		numfmt --to=iec --suffix=B "$1"
	}
	# shellcheck disable=2312
	echo "Seedbox workspace is too big: $(format "$size"). Max size: $(format "$max_size")" >&2
	exit 1
fi
