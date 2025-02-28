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
set --global fish_color_keyword $fish_color_normal --bold
set --global fish_color_quote brcyan
set --global fish_color_redirection
set --global fish_color_end $fish_color_keyword
set --global fish_color_error red
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
set --global fish_color_autosuggestion brblack --bold
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

# Don't print a greeting when a new interactive fish shell is started
set --global fish_greeting ''

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
                | fzf  \
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
mybind --no-focus \cz _resume_job

# use shift+right-arrow to accept the next suggested word
mybind \e\[1\;2C forward-word

# use ctrl+b to jump to beginning of line
mybind \cb beginning-of-line

# ctrl+r to refresh terminal, shell, and screen
#
# Set the binding on fish_prompt since something else was overriding it.
function __set_reload_keybind --on-event fish_prompt
    # I only want this to run once so delete the function.
    functions -e (status current-function)
    mybind --no-focus \cr 'reset && exec fish && clear'
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

# Use tab to select an autocomplete entry with fzf
#
# TODO: When the builtin fuzzy pager supports selecting multiple items I can
# probably switch back to it:
# https://github.com/fish-shell/fish-shell/issues/1898
function _insert_entries_into_commandline
    # Remove the tab and description, leaving only the completion items.
    set entries $(string split -f1 -- \t $argv)
    set entry (string join -- ' ' $entries)

    set space ' '

    # None of this applies if there are multiple entries
    if test (count $entries) -eq 1
        # Don't add a space if the entry is an abbreviation.
        #
        # TODO: This assumes that an abbreviation can only be expanded if
        # it's the first token in the commandline.  However, with the flag
        # '--position anywhere', abbreviations can be expanded anywhere in the
        # commandline so I should check for that flag.
        #
        # We determine if the entry will be the first token by checking for
        # an empty commandline. We trim spaces because spaces don't count as
        # tokens. We also check for a commandline with a single token where the
        # character before the cursor isn't a space e.g. `prefix|`.
        set commandline "$(commandline)"
        set trimmed_commandline (string trim "$commandline")
        if test -z "$trimmed_commandline"
            set is_first 1
        else
            set token_count (count (string split --no-empty -- ' ' "$commandline"))
            set last_char (string sub --start -1 -- "$commandline")
            if test "$token_count" -eq 1
                and test "$last_char" != ' '
                set is_first 1
            end
        end
        if abbr --query -- "$entry"
            and test -n "$is_first"
            set space ''
        end

        # Don't add a space if the item is a directory and ends in a slash.
        #
        # Use eval so expansions are done e.g. environment variables,
        # tildes. For scenarios like (bar is cursor) `echo "$HOME/|"` where the
        # autocomplete entry will include the left quote, but not the right
        # quote. I remove the left quote so `test -d` works.
        if test "$(string sub --length 1 --start 1 -- "$entry")" = '"'
            and test "$(string sub --start -1 -- "$entry")" != '"'
            set balanced_quote_entry (string sub --start 2 -- "$entry")
        else
            set balanced_quote_entry "$entry"
        end
        if eval test -d "$balanced_quote_entry" && test "$(string sub --start -1 -- "$entry")" = /
            set space ''
        end
    end

    # retain the part of the token after the cursor. use case: autocompleting
    # inside quotes (bar is cursor) `echo "$HOME/|"`
    set token_after_cursor "$(string sub --start (math (string length -- "$(commandline --current-token --cut-at-cursor)") + 1) -- "$(commandline --current-token)")"
    set replacement "$entry$space$token_after_cursor"

    # if it ends in `""` or `" "` (when we add a space), remove one quote. use
    # case: autocompleting a file inside quotes (bar is cursor) `echo "/|"`
    set replacement (string replace --regex -- '"'$space'"$' $space'"' "$replacement")
    or set replacement (string replace --regex -- "'$space'\$" $space"'" "$replacement")

    commandline --replace --current-token -- "$replacement"
end
function _fzf_complete
    set candidates (complete --escape --do-complete -- "$(commandline --cut-at-cursor)")
    set candidate_count (count $candidates)
    # I only want to repaint if fzf is shown, but if I use `fzf --select-1` fzf
    # won't be shown when there's one candidate and there is no way to tell
    # if that's how fzf exited so instead I'll check the amount of candidates
    # beforehand an only use fzf is there's more than 1. Same situation with
    # --exit-0.
    if test $candidate_count -eq 1
        _insert_entries_into_commandline $candidates
    else if test $candidate_count -gt 1
        set current_token (commandline --current-token --cut-at-cursor)
        if set entries ( \
            printf %s\n $candidates \
            # Use a different color for the completion item description
            | string replace --ignore-case --regex -- \
                '(?<prefix>^'(string escape --style regex -- "$current_token")')(?<item>[^\t]*)((?<whitespace>\t)(?<description>.*))?' \
                (set_color cyan)'$prefix'(set_color normal)'$item'(set_color brblack)'$whitespace$description' \
            | fzf \
                --height (math "max(6,min(10,$(math "floor($(math .35 \* $LINES))")))") \
                --preview-window '2,border-left,right,60%' \
                --no-header \
                --bind 'backward-eof:abort,start:toggle-preview' \
                --no-hscroll \
                --tiebreak=begin,chunk \
                # I set the current token as the delimiter so I can exclude
                # from what gets searched.  Since the current token is in the
                # beginning of the string, it will be the first field index so
                # I'll start searching from 2.
                --delimiter '^'(string escape --style regex -- $current_token) \
                --nth '2..' \
                --border rounded \
                --margin 0,2,0,2 \
                --prompt $current_token \
                --no-separator \
        )
            _insert_entries_into_commandline $entries
        end
        commandline -f repaint
    end
end
# Set the binding on fish_prompt since something else was overriding it during
# shell startup.
function __set_fzf_tab_complete --on-event fish_prompt
    # I only want this to run once so delete the function.
    functions -e (status current-function)
    mybind --no-focus \t _fzf_complete
end
# Keep normal tab complete on shift+tab to expand wildcards.
mybind -k btab complete

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

mybind --no-focus \ck __fish_man_page

# navigate history
mybind --key f7 up-or-search
mybind --key f8 down-or-search

# While the builtin edit_command_buffer retains the cursor position when going from
# the command line to the editor, this one also retains the cursor position when
# going from the editor back to the command line.
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
mybind \ee __edit_commandline

# fish loads builtin configs after user configs so I have to wait
# for the builtin binds to be defined. This may change though:
# https://github.com/fish-shell/fish-shell/issues/8553
function __remove_paginate_keybind --on-event fish_prompt
    # I only want this to run once so delete the function.
    functions -e (status current-function)
    bind --erase --preset \ep
end

# ghostty
if set --query GHOSTTY_RESOURCES_DIR
    source "$GHOSTTY_RESOURCES_DIR/shell-integration/fish/vendor_conf.d/ghostty-shell-integration.fish"
end

functions --erase fish_command_not_found
