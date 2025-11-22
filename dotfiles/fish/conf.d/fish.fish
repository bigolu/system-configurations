# I'm defining this before the interactivity check so I can call this from
# non-interactive shells. This way I can reload my shells from a script.
function fish-reload
    set --universal _fish_reload_indicator (random)
end

if not status is-interactive
    exit
end

# Sets the cursor shape to a blinking bar
printf '\033[5 q'

set --global fish_color_normal
set --global fish_color_command $fish_color_normal
set --global fish_color_keyword $fish_color_normal
set --global fish_color_quote brcyan
set --global fish_color_redirection
set --global fish_color_end $fish_color_keyword
set --global fish_color_error --underline=curly ---underline-color red
set --global fish_color_param $fish_color_normal
set --global fish_color_option $fish_color_normal
set --global fish_color_comment brblack
set --global fish_color_match
set --global fish_color_search_match --background=brblack
# TODO: I want to remove the default bolding, but currently only the background
# is configurable.
# Issue: https://github.com/fish-shell/fish-shell/issues/2442
set --global fish_pager_color_selected_background --background=brblack
set --global fish_color_operator $fish_color_normal
set --global fish_color_escape $fish_color_redirection
set --global fish_color_cwd
set --global fish_color_autosuggestion brblack --italics
set --global fish_color_user
set --global fish_color_host
set --global fish_pager_color_prefix cyan
set --global fish_pager_color_completion
set --global fish_pager_color_description
set --global fish_pager_color_progress --background=brblack normal
set --global fish_pager_color_secondary
set --global fish_color_cancel $fish_color_autosuggestion
set --global fish_color_valid_path

abbr --add --global r fish-reload
bind ctrl-b beginning-of-line
bind ctrl-k __fish_man_page
functions --erase fish_command_not_found

# Don't print a greeting when a new interactive fish shell is started
set --global fish_greeting ''

# navigate history
bind ctrl-\[ up-or-search
bind ctrl-\] down-or-search

# Set the binding on fish_prompt since something else was overriding it during
# shell startup.
function __set_tab_bind --on-event fish_prompt
    # I only want this to run once so delete the function.
    functions -e (status current-function)

    bind tab '
        if commandline --search-field >/dev/null
            commandline -f complete
        else
            commandline -f complete-and-search
        end
    '

    bind shift-tab '
        if commandline --search-field >/dev/null
            commandline -f complete-and-search
        else
            commandline -f complete
        end
    '
end

# use ctrl+z to resume the most recently suspended job
function _resume_job
    if not jobs --query
        return
    end

    set job_count (jobs | wc -l)

    if test "$job_count" -eq 1
        fg 1>/dev/null 2>&1

        # this should be done whenever a binding produces output (see: man bind)
        commandline -f repaint

        return
    end

    set delimiter ':delim:'
    set entries
    for job_pid in (jobs --pid)
        set job_command (ps -o command= -p "$job_pid")
        set --append entries "$job_pid$delimiter$job_command"
    end

    set choice \
        ( \
            # I'm using the NUL character to delimit entries since they may span
            # multiple lines.
            printf %s'\0' $entries \
                | fzf \
                    --read0 \
                    --delimiter $delimiter \
                    --with-nth '2..' \
                    --no-preview \
                    --height ~30% \
                    --margin 0,2,0,2 \
                    --border rounded \
                    --no-multi \
                | string replace \n '␊' \
        )
    if test -n "$choice"
        set tokens (string split $delimiter "$choice")
        set pid $tokens[1]
        fg "$pid" 1>/dev/null 2>&1
    end

    # this should be done whenever a binding produces output (see: man bind)
    commandline -f repaint
end
bind ctrl-z _resume_job

# Set the binding on fish_prompt since something else was overriding it.
function __set_reload_keybind --on-event fish_prompt
    functions -e (status current-function)
    bind ctrl-r 'reset && exec fish && clear'
end

# search variables
function variable-widget --description 'Search shell/environment variables'
    for name in (set --names)
        set value (set --show $name)
        set entry "$name"\t"$(string join \n $value)"
        set --append entries $entry
    end

    # I'm using the NUL character to delimit entries since they may span
    # multiple lines.
    if not set choices ( \
        printf %s'\0' $entries \
            | fzf \
                --read0 \
                --print0 \
                --delimiter \t \
                --with-nth 1 \
                --preview 'echo {2..}' \
                --prompt '$' \
            | string split0 \
    )
        return
    end

    for choice in $choices
        set name (string split --fields 1 -- \t $choice)
        set --append chosen_names $name
    end

    if not set choice ( \
        printf %s'\n' name value \
        | fzf \
            --prompt 'output type: ' \
            --no-preview
    )
        return
    end

    set to_insert
    for chosen_name in $chosen_names
        if test $choice = value
            set --append to_insert $$chosen_name
        else
            set --append to_insert $chosen_name
        end
    end

    echo $to_insert
end
abbr --add --global vw variable-widget

# Reload all fish instances
function _reload_fish --on-variable _fish_reload_indicator
    if jobs --query
        echo -n -e "\n$(set_color --reverse --bold yellow) WARNING $(set_color normal) The shell will not reload since there are jobs running in the background.$(set_color normal)"
        commandline -f repaint
        return
    end

    # TODO: This will leave the old prompt on the screen. I think this happens
    # because exec is being called from a handler. When I call exec from the
    # commandline, the prompt is properly redrawn. I should file an issue to see if
    # this is expected.
    exec fish
end

function _maybe_escape --argument-names token
    if test (string sub --start 1 --length 1 -- $token) != '~'
        string escape --style script -- $token
    else
        echo -- $token
    end
end

# Bash-Style history expansion
function _bash_style_history_expansion
    set token "$argv[1]"
    set last_command "$history[1]"
    printf '%s' "$last_command" | read --tokenize --list last_command_tokens

    if test "$token" = '!!'
        echo "$last_command"
    else if test "$token" = '!^'
        _maybe_escape $last_command_tokens[1]
    else if test "$token" = '!$'
        _maybe_escape $last_command_tokens[-1]
    else if string match --quiet --regex -- '\!\-?\d+:?' "$token"
        set last_command_token_index (string match --regex -- '\-?\d+' "$token")
        set absolute_value (math abs "$last_command_token_index")
        if test "$absolute_value" -gt (count $last_command_tokens)
            return 1
        end
        if test (string sub --start -1 $token) = ':'
            set escaped
            for item in $last_command_tokens[$last_command_token_index..]
                set --append escaped (_maybe_escape $item)
            end
            echo "$escaped"
        else
            _maybe_escape $last_command_tokens[$last_command_token_index]
        end
    else
        return 1
    end
end
abbr --add bash_style_history_expansion \
    --position anywhere \
    --regex '\!(\!|\^|\$|\-?\d+:?)' \
    --function _bash_style_history_expansion

# While the builtin edit_command_buffer retains the cursor position when going from
# the command line to the editor, this one also retains the cursor position when
# going from the editor back to the command line.
#
# TODO: Upstream
function __edit_commandline
    set buffer "$(commandline)"
    set index (commandline --cursor)
    set line 1
    set col 1
    set cursor 0

    for char in (string split '' "$buffer")
        if test $cursor -ge $index
            break
        end

        if test "$char" = \n
            set col 1
            set line (math $line + 1)
        else
            set col (math $col + 1)
        end

        set cursor (math $cursor + 1)
    end

    set cursor_file (mktemp)
    set write_index 'lua vim.api.nvim_create_autocmd([[VimLeavePre]], {callback = function() vim.cmd([[redi! > '$cursor_file']]); print(#table.concat(vim.fn.getline(1, [[.]]), " ") - (#vim.fn.getline([[.]]) - vim.fn.col([[.]])) - 1); vim.cmd([[redi END]]); end})'

    set temp (mktemp --suffix '.fish')
    echo -n "$buffer" >$temp
    nvim -c "call cursor($line,$col)" -c "$write_index" $temp
    commandline "$(cat $temp)"
    commandline --cursor "$(cat $cursor_file)"
end
bind alt-e __edit_commandline

# fish loads builtin configs after user configs so I have to wait
# for the builtin binds to be defined. This may change though:
# https://github.com/fish-shell/fish-shell/issues/8553
function __remove_paginate_keybind --on-event fish_prompt
    # I only want this to run once so delete the function.
    functions -e (status current-function)
    bind --erase --preset alt-p
end
