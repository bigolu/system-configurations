# I prepend zz to the filename so it runs after other configs. This way the nix
# wrapper won't get overwritten.

if not status is-interactive
    exit
end

function nix
    # If I'm running the repl, use my startup file.
    if test (count $argv) -eq 1 -a "$argv[1]" = repl
        set xdg_config (test -n "$XDG_CONFIG_HOME" && echo $XDG_CONFIG_HOME || echo "$HOME/.config")
        command nix $argv --file "$xdg_config/nix/repl-startup.nix"
    else if test (count $argv) -eq 2 -a "$argv[1]" = flake -a "$argv[2]" = show
        # There's an open issue for omitting more information from `flake show`, but
        # this workaround was suggested in the meantime[1].
        #
        # To avoid interspersing nix's progress messages (e.g. "evaluating x...")
        # with ripgrep's output, I'm suppressing the messages.
        #
        # [1]: https://github.com/NixOS/nix/issues/9011
        command nix flake show 2>/dev/null | rg -v omitted
    else
        command nix $argv
    end
end

function nix-store-size
    numfmt --to=iec-i --suffix=B --format="%9.2f" (nix path-info --json --all | jq 'map(.narSize) | add')
end
