# shellcheck shell=bash

# If not running interactively, exit this script.
# Reasoning is explained here: https://unix.stackexchange.com/questions/257571/why-does-bashrc-check-whether-the-current-shell-is-interactive
if [ -z "$PS1" ]; then
	return
fi

# Set color palette for tty. It is the same as the dark theme I use in my regular terminal.
if [ "$TERM" = "linux" ]; then
    printf "\e]P0232731"
    printf "\e]P8333745"
    printf "\e]P1BF616A"
    printf "\e]P9BF616A"
    printf "\e]P2A3BE8C"
    printf "\e]PAA3BE8C"
    printf "\e]P3EBCB8B"
    printf "\e]PBEBCB8B"
    printf "\e]P481A1C1"
    printf "\e]PC81A1C1"
    printf "\e]P5B48EAD"
    printf "\e]PD232731"
    printf "\e]P688C0D0"
    printf "\e]PE8FBCBB"
    printf "\e]P7E5E9F0"
    printf "\e]PF626f89"
    clear #for background artifacting

    # Enable 256 color mode for fbterm
    # [ -n "$FBTERM" ] && export TERM=fbterm
fi

# If the current shell isn't fish, use fish in place of bash for an interactive shell.
# WARNING: Keep this line at the bottom of the file since nothing after this line will be executed.
[ "$(basename "$SHELL")" != 'fish' ] && command -v fish >/dev/null 2>&1 && SHELL="$(command -v fish)" exec fish