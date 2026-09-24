#!/usr/bin/env nu

use std/assert

let context = if CONTEXT in $env {
  $env.CONTEXT | from json
} else {
  let seedbox_project_root = $"($env.PRJ_ROOT)/program-configs/seedbox"
  {
    qbittorrentConfig: $"($seedbox_project_root)/qBittorrent.conf"
    watchedFolders: $"($seedbox_project_root)/watched_folders.json"
    autobrrConfig: $"($seedbox_project_root)/config.toml"
  }
}

let workspace = $"($env.HOME)/.local/state/seedbox"
mkdir $workspace
cd $workspace

$env.XDG_CONFIG_HOME = $"($workspace)/config"
$env.XDG_DATA_HOME = $"($workspace)/data"

do {
  let workspace_qbittorrent_config = $"($env.XDG_CONFIG_HOME)/qBittorrent/qBittorrent.conf"
  # Since the watched folder doesn't seem to be respected unless I set it through
  # the web UI, I don't want to overwrite any qbittorrent configs.
  if not ($workspace_qbittorrent_config | path exists) {
    mkdir ($workspace_qbittorrent_config | path dirname)
    cp $context.qbittorrentConfig $workspace_qbittorrent_config

    let default_save_path = $"($workspace)/torrent-content"
    mkdir $default_save_path
    open $workspace_qbittorrent_config
    | str replace 'default_save_path' $default_save_path
    | save --force $workspace_qbittorrent_config
  }
}

do {
  let workspace_watched_folders = $"($env.XDG_CONFIG_HOME)/qBittorrent/watched_folders.json"
  # Since the watched folder doesn't seem to be respected unless I set it through
  # the web UI, I don't want to overwrite any qbittorrent configs.
  if not ($workspace_watched_folders | path exists) {
    mkdir ($workspace_watched_folders | path dirname)
    cp $context.watchedFolders $workspace_watched_folders

    let download_dir = $"($workspace)/torrent-files"
    mkdir $download_dir
    open $workspace_watched_folders
    | str replace 'download_dir' $download_dir
    | save --force $workspace_watched_folders
  }
}

do {
  let workspace_autobrr_config = $"($env.XDG_CONFIG_HOME)/autobrr/config.toml"
  mkdir ($workspace_autobrr_config | path dirname)
  cp $context.autobrrConfig $workspace_autobrr_config
}

# Setup:
#   1. If the watched folder isn't being respected, unset it and set it again in
#      the web UI.
let qbittorrentId = job spawn { qbittorrent-nox --confirm-legal-notice }

# Setup:
#   1. Configure the RSS feed: Max 25Gb per torrent, freeleech
#   2. Make a filter: Add an action to put file in the watch directory and an
#      external exec filter that runs autobrr-filter
let autobrrId = job spawn { autobrr --config $"($env.XDG_CONFIG_HOME)/autobrr" }

# Issue for adding support for waiting on jobs[1].
#
# [1]: https://github.com/nushell/nushell/issues/15198
loop {
  let job_ids = job list | get id
  assert ($qbittorrentId in $job_ids and $autobrrId in $job_ids) 'Background job died'
  sleep 1sec
}
