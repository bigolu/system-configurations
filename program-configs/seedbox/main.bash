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

workspace_config="$workspace/config"
export XDG_CONFIG_HOME="$workspace_config"

workspace_data="$workspace/data"
export XDG_DATA_HOME="$workspace_data"

download_dir="$workspace/torrent-files"
mkdir --parents "$download_dir"

default_save_path="$workspace/torrent-content"
mkdir --parents "$default_save_path"

if [[ $dev == true ]]; then
	qbittorrent_config="$PRJ_ROOT/program-configs/seedbox/qBittorrent.conf"
else
	qbittorrent_config=@qbittorrent_config@
fi
if [[ ! -e "$workspace_config/qBittorrent/qBittorrent.conf" ]]; then
	install -D "$qbittorrent_config" "$workspace_config/qBittorrent/qBittorrent.conf"
	sd 'default_save_path' "$default_save_path" "$workspace_config/qBittorrent/qBittorrent.conf"
fi

if [[ $dev == true ]]; then
	autobrr_config="$PRJ_ROOT/program-configs/seedbox/config.toml"
else
	autobrr_config=@autobrr_config@
fi
install -D "$autobrr_config" "$workspace_config/autobrr/config.toml"

# Setup:
#   1. Make `download_dir` a watched folder. For some reason, it doesn't work
#      when I set it in the config.
qbittorrent-nox &

# Setup:
#   1. Configure the RSS feed: Max 10Gb per torrent, freeleech
#   2. Make a filter: Add an action to put file in the watch directory and an
#      external exec filter that runs autobrr-filter
export PATH="@autobrr_filter_bin@${PATH:+:$PATH}"
autobrr --config "$workspace_config/autobrr" &

# Fail if any background job exits
wait -n
exit 1
