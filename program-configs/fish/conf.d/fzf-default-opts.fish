# Normally I check if the shell is interactive, but I need to run this even when
# the shell is non-interactive so I can call the fish functions defined here
# from fzf bindings.

set accent_color cyan

set --local xdg_data (test -n "$XDG_DATA_HOME" && echo "$XDG_DATA_HOME" || echo "$HOME/.local/share")
set --local xdg_config (test -n "$XDG_CONFIG_HOME" && echo $XDG_CONFIG_HOME || echo "$HOME/.config")

set _bigolu_fzf_help_text " $(set_color $accent_color)ctrl+h$(set_color normal) show help page "

# TODO: I use the indicator to tell which state we are in, but if fzf adds a
# variable for the content of the 'info' section, I could just use that since
# they put a '+T' in there when you're tracking.
function _bigolu_track_toggle
    set indicator "  "
    set new "$FZF_PROMPT"
    if set new (string replace -- "$indicator" "" "$new")
        set bind "rebind(change)"
    else
        set new "$indicator$FZF_PROMPT"
        set bind "unbind(change)"
    end
    echo "toggle-track+change-prompt($new)+$bind"
end

function _bigolu_fzf_preview_toggle --argument-names name keybind preview
    if not string match --quiet --regex -- ".*$name.*go back.*" "$FZF_BORDER_LABEL"
        echo "preview($preview)+preview-top+change-border-label@ $name ($(set_color $accent_color)$keybind$(set_color normal) to go back) @"
    else
        echo "refresh-preview+change-border-label@$_bigolu_fzf_help_text@"
    end
end

function _bigolu_selected_toggle
    _bigolu_fzf_preview_toggle 'selected items' 'ctrl+s' 'printf %s\n {+}'
end

function _bigolu_help_toggle
    _bigolu_fzf_preview_toggle 'help page' 'ctrl+h' fzf-help-preview
end

# Certain actions can cause fzf to leave the help/selected-entries preview.
# After executing one of those actions, we need to see the label back to the
# original.
#
# TODO: I should also run this on the 'focus' event, but it makes selecting
# items very slow.
function _bigolu_fix_label
    echo "change-border-label($_bigolu_fzf_help_text)"
end

set --export FZF_DEFAULT_OPTS_FILE "$xdg_config/fzf/fzfrc.txt"
set --export FZF_DEFAULT_OPTS "--history=$xdg_data/fzf/fzf-history.txt"
