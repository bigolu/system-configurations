#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ -n ${PRJ_ROOT:-} ]]; then
	dev=true
else
	dev=false
fi

workspace=~/.local/state/seedbox
mkdir --parents "$workspace"
cd "$workspace"

export XDG_CONFIG_HOME="$workspace/config"
export XDG_DATA_HOME="$workspace/data"

if [[ $dev == true ]]; then
	qbittorrent_config="$PRJ_ROOT/program-configs/seedbox/qBittorrent.conf"
else
	qbittorrent_config=@qbittorrent_config@
fi
# qbittorrent may modify this file so once we've copied it, we shouldn't copy it
# again.
workspace_qbittorrent_config="$XDG_CONFIG_HOME/qBittorrent/qBittorrent.conf"
if [[ ! -e $workspace_qbittorrent_config ]]; then
	install -D "$qbittorrent_config" "$workspace_qbittorrent_config"

	default_save_path="$workspace/torrent-content"
	mkdir --parents "$default_save_path"
	sd 'default_save_path' "$default_save_path" "$workspace_qbittorrent_config"
fi

if [[ $dev == true ]]; then
	watched_folders="$PRJ_ROOT/program-configs/seedbox/watched_folders.json"
else
	watched_folders=@watched_folders@
fi
# qbittorrent may modify this file so once we've copied it, we shouldn't copy it
# again.
workspace_watched_folders="$XDG_CONFIG_HOME/qBittorrent/watched_folders.json"
if [[ ! -e $workspace_watched_folders ]]; then
	install -D "$watched_folders" "$workspace_watched_folders"

	download_dir="$workspace/torrent-files"
	mkdir --parents "$download_dir"
	sd 'download_dir' "$download_dir" "$workspace_watched_folders"
fi

if [[ $dev == true ]]; then
	autobrr_config="$PRJ_ROOT/program-configs/seedbox/config.toml"
else
	autobrr_config=@autobrr_config@
fi
install -D "$autobrr_config" "$XDG_CONFIG_HOME/autobrr/config.toml"

# Setup:
#   1. If the watched folder isn't being respected, unset it and set it again in
#      the web UI.
qbittorrent-nox &

# Setup:
#   1. Configure the RSS feed: Max 10Gb per torrent, freeleech
#   2. Make a filter: Add an action to put file in the watch directory and an
#      external exec filter that runs autobrr-filter
export PATH="@autobrr_filter_bin@${PATH:+:$PATH}"
autobrr --config "$XDG_CONFIG_HOME/autobrr" &

# Fail if any background job exits
wait -n
exit 1
