#!/usr/bin/env nu

use std/assert

let workspace = $env.XDG_STATE_HOME? | default $"($env.HOME)/.local/state" | $"($in)/seedbox"
let max_size = 400GiB
let max_torrents = 20

def main [torrent] {
  $torrent
  | append (glob $"($workspace)/data/qBittorrent/BT_backup/*.torrent")
  | par-each {
				imdl torrent show --json $in
					| from json
					| get content_size
					| into filesize
			}
  | math sum
  | assert ($in <= $max_size) $'Total torrent size is too big: ($in). Max size: ($max_size)'

  # Fail-Safe in case qbittorrent moves the torrent directory
  du $workspace
  | get 0.physical
  | assert ($in <= $max_size) $'Workspace is too big: ($in). Max size: ($max_size)'

  # Fail-Safe in case qbittorrent isn't automatically adding the torrents.
  glob $"($workspace)/torrent-files/*.torrent"
  | length
  | assert ($in <= $max_torrents) $'Autobrr torrent count exceeded: ($in). Max count: ($max_torrents)'
}
