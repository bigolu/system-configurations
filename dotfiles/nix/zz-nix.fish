# I prepend zz to the filename so it runs after other configs. This way the nix
# wrapper won't get overwritten.

if not status is-interactive
    exit
end

function nix
    # If I'm starting the repl, start it with my startup file.
    if test (count $argv) -eq 1 -a "$argv[1]" = repl
        set xdg_config (test -n "$XDG_CONFIG_HOME" && echo $XDG_CONFIG_HOME || echo "$HOME/.config")
        set --append argv --file "$xdg_config/nix/repl-startup.nix"
    end
    command nix $argv
end

function nix-store-size
    numfmt --to=iec-i --suffix=B --format="%9.2f" (nix path-info --json --all | jq 'map(.narSize) | add')
end
