if not status is-interactive
    exit
end


set xdg_data (test -n "$XDG_DATA_HOME" && echo "$XDG_DATA_HOME" || echo "$HOME/.local/share")
set _fzf_history_file "$xdg_data/fzf/fzf-history.txt"
set _magnifying_glass (echo -s \uf002 '  ')

set --global --export FZF_DEFAULT_OPTS "
    --cycle
    --ellipsis='…'
    --bind 'tab:down,shift-tab:up,ctrl-j:preview-down,ctrl-k:preview-up,change:first,ctrl-o:change-preview-window(right,60%|bottom,75%)+refresh-preview,ctrl-/:preview(fzf-help-preview)+preview-top,ctrl-\\:refresh-preview,enter:accept,ctrl-r:refresh-preview,ctrl-w:toggle-preview-wrap,alt-enter:toggle,ctrl-t:track+unbind(change),focus:rebind(change)'
    --layout=reverse
    --border=none
    --color='16,fg:dim,fg+:-1:regular:underline,bg+:-1,info:15,gutter:8,pointer:-1:bold,prompt:6:regular,border:15:dim,query:-1:regular,marker:-1:bold,header:15,spinner:yellow,hl:cyan:dim,hl+:regular:cyan:underline'
    --margin=3%
    --height 100%
    --prompt='$_magnifying_glass'
    --tabstop=2
    --info=inline
    --pointer='>'
    --marker='>'
    --history='$_fzf_history_file'
    --header=' '
    --preview='echo {}'
    --preview-window=wrap,bottom,75%
    --multi
    --no-separator
    --scrollbar='🮈'
    --preview-label ' press ctrl+/ for help '
    --preview-label-pos '-3:bottom'
    --ansi
    "

set --global --export FZF_ALT_C_COMMAND 'test $dir = '.' && set _args "--strip-cwd-prefix" || set _args '.' $dir; fd $_args --follow --hidden --type directory --type symlink'
set --global --export FZF_ALT_C_OPTS "--preview 'type --query lsd; and lsd {}; or ls {}' --keep-right --bind='change:first'"

set --global --export FZF_CTRL_R_OPTS '--prompt="history: " --preview "echo {}"'

# use ctrl+h for history search instead of default ctrl+r
bind --erase \cr
# I merge the history so that the search will search across all fish sessions' histories.
#
# TODO: The script in conf.d for the plugin 'jorgebucaran/autopair.fish' is deleting my ctrl+h keybind
# that I define in here. As a workaround, I set this keybind when the first prompt is loaded which should be after
# autopair is loaded.
function __set_fzf_history_keybind --on-event fish_prompt
    # I only want this to run once so delete the function.
    functions -e (status current-function)
    bind-no-focus \ch 'history merge; fzf-history-widget'
end

# use alt+d for directory search instead of default alt+c
bind --erase \ec
bind-no-focus \ed 'FZF_ALT_C_OPTS="$FZF_ALT_C_OPTS --prompt=\'$(prompt_pwd)/\'" fzf-cd-widget'

# Workaround to allow me to use fzf-tmux-zoom with the default widgets that come with fzf.
# The default widgets use __fzfcmd to get the name of the fzf command to use so I am
# overriding it here.
function __fzfcmd
    echo fzf-tmux-zoom
end

mkdir -p (dirname $_fzf_history_file)
touch $_fzf_history_file