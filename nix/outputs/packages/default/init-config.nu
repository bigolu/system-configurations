#!/usr/bin/env nu

use std/assert

def main [config] {
  do --env {
    let project_dir = $"($nu.home-dir)/code/system-configurations"
    if not ($project_dir | path exists) {
      git clone https://github.com/bigolu/system-configurations.git $project_dir
    }
    cd $project_dir
  }

  if DID_LOAD_DIRENV in $env {

    # Besides passing positional arguments, this is done separately from other syncs
    # since it may prompt the user and `hk`, which is called by `mise run sync`,
    # seems to have a bug where it can't take user input despite me enabling the
    # `interactive` setting.
    mise run hk:system-sync $config
    with-env { HK_SKIP_STEPS: 'system' } { mise run sync }
    exit
  }

  "source .envrc-recommended.bash" | save --force .envrc
  direnv allow
  let nix_config = $"($env.PWD)/program-configs/nix/nix.conf"
  assert ($nix_config | path exists) 'Nix config does not exist'
  # Use the caches set in the nix config
  #
  # We can't use `NIX_CONFIG` since the config file uses relative paths and lix
  # forbids their use in `NIX_CONFIG`.
  with-env {
		NIX_USER_CONF_FILES: $nix_config
		DID_LOAD_DIRENV: 'true'
	} {
		const self = path self
		direnv exec . nu $self $config
	}
}
