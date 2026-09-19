#nix --interpreter nu --packages nushell coreutils s nh system-manager dix
#MISE hide=true
#USAGE arg "[config]" help="The name of the configuration to apply"

let sudo = [ sudo (which s).0.path ]

# The default sudoers config on Pop!_OS doesn't allow most environment variables
# to be inherited.
let env = env --null
	| str trim --right --char (char nul)
	| split row (char nul)
	| prepend (which env).0.path

let config = $env.usage_config?
	| default ($env.XDG_STATE_HOME? | default $"($env.HOME)/.local/state" | open --raw $"($in)/bigolu/system-config-name" | str trim)
let command = if $nu.os-info.name == linux {
	if $env.ASK? == 'true' {
		(
			dix
				/nix/var/nix/profiles/system-manager-profiles/system-manager
				(nix build --no-link --print-out-paths --file . $"outputs.systemConfigs.($config)")
		)

		input --numchar 1 'Apply the configuration? (y/n): '
			| str trim
			| str downcase
			| if $in != y { exit }
	}

	[system-manager switch --sudo --flake $".#systemConfigs.($config)"]
} else {
	let ask = if $env.ASK? == 'true' { [ --ask ] } else { [] }
	[ nh darwin switch --show-activation-logs ...$ask --file . $"outputs.darwinConfigurations.($config)" ]
}

try {
	run-external ...$sudo ...$env ...$command
} finally {
	if $nu.os-info.name == linux {
		systemctl show -p InvocationID --value $"home-manager-($env.USER).service"
			| journalctl --no-pager --output cat $"_SYSTEMD_INVOCATION_ID=($in)"
			| find --invert pam_unix COMMAND=
			| str join "\n"
	}
}
