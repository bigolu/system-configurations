if not status is-interactive
    exit
end

function __widgets_get_directory_from_current_token
    set dir "$(commandline -t)"
    if test "$(string sub --length 1 -- "$dir")" = '~'
        set dir (string replace '~' "$HOME" "$dir")
    end
    if not test -d (string unescape --style=script "$dir")
        set dir '.'
    end

    echo $dir
end

function __widgets_format_directory_for_prompt --argument-names dir
    set dir (string unescape $dir)
    set prompt (string replace "$HOME" '~' "$dir")
    if test "$(string sub --start -1 "$dir")" != /
        set prompt "$prompt/"
    end

    echo $prompt
end

function __widgets_replace_current_commandline_token
    set replacement_tokens $argv
    set escaped_replacement_tokens (string escape --style script --no-quoted -- $replacement_tokens)

    # add a space if the item is a file or directory not ending in a slash.
    set last_token $escaped_replacement_tokens[-1]
    if test -f $last_token -o \( -d $last_token -a (string sub --start -1 -- $last_token) != / \)
        set escaped_replacement_tokens[-1] $last_token' '
    end

    commandline --current-token --replace "$escaped_replacement_tokens"
end

set __directory_placeholder '{bigolu_dir}'
function __grep_widget --argument-names title grep_command
    set dir (__widgets_get_directory_from_current_token)

    set escaped_dir (string escape --no-quoted --style script -- $dir)
    set grep_command (string replace --all $__directory_placeholder $escaped_dir $grep_command)

    set prompt_directory ''
    if test $dir != '.'
        set prompt_directory $dir
        if test "$(string sub --start -1 "$dir")" = /
            set prompt_directory (string sub --end=-1 $prompt_directory)
        end
        set prompt_directory '('(string unescape --style=script $prompt_directory)') '
    end

    if not set choices ( \
        FZF_DEFAULT_COMMAND="echo -n ''" \
        FZF_HINTS='alt+e: edit in neovim' \
        fzf \
            --disabled \
            # We refresh-preview after executing vim in the event that the file
            # gets modified by vim. Tracking doesn't work when the input list is
            # reloaded so I'm binding it to a no-op.
            --bind "ctrl-t:execute-silent(:),alt-e:execute(nvim '+call cursor({2},{3})' {1} < /dev/tty > /dev/tty 2>&1)+refresh-preview,change:first+reload:sleep 0.1; $grep_command || true" \
            --delimiter ':' \
            --prompt $prompt_directory$title \
            --preview-window '+{2}/3,75%,~1' \
            # the minus 2 prevents a weird line wrap issue
            #
            # wrap=never is there so the preview window is moved to the current
            # line
            --preview 'bat --style=\'header-filename\' --color always --wrap=never --paging=never --terminal-width (math $FZF_PREVIEW_COLUMNS - 2) {1} --highlight-line {2}' \
    )
        return
    end

    set choices (string split --fields 1 -- ':' $choices)
    __widgets_replace_current_commandline_token $choices

    # this should be done whenever a binding produces output (see: man bind)
    commandline -f repaint
end

function grep-widget --description 'Search by line, recursively, from current directory'
    __grep_widget \
        'pattern: ' \
        "rg --no-config --colors=match:none --colors=match:fg:cyan --colors=path:none --colors=line:none --colors=line:fg:8 --colors=column:none --hidden --column --line-number --no-heading --color=always --smart-case --follow --no-ignore-parent -- {q} $__directory_placeholder"
end
bind ctrl-g grep-widget

function grep-all-widget --description 'Text search on text, and certain non-text, files, recursively, from current directory'
    set dir (__widgets_get_directory_from_current_token)

    set grep_command "rga --files-with-matches --rga-cache-max-blob-len=10M -- {q} $__directory_placeholder"
    set grep_command (string replace --all $__directory_placeholder (string escape --no-quoted --style script -- $dir) $grep_command)

    set prompt_directory ''
    if test $dir != '.'
        set prompt_directory $dir
        if test "$(string sub --start -1 "$dir")" = /
            set prompt_directory (string sub --end=-1 $prompt_directory)
        end
        set prompt_directory '('(string unescape --style=script $prompt_directory)') '
    end

    if not set choices ( \
        FZF_DEFAULT_COMMAND="echo -n ''" \
        fzf \
            --disabled \
            # tracking doesn't work when the input list is reloaded so I'm
            # binding it to a no-op.
            --bind "ctrl-t:execute-silent(:),change:first+reload:sleep 0.1; $grep_command || true" \
            --bind "start:reload:$(string replace --all -- '{q}' \"''\" $grep_command)" \
            --prompt $prompt_directory'pattern: ' \
            --preview 'rga --pretty --context 5 {q} --rga-fzf-path=_{}' \
    )
        return
    end

    __widgets_replace_current_commandline_token $choices

    # this should be done whenever a binding produces output (see: man bind)
    commandline -f repaint
end
bind alt-g grep-all-widget

function ast-grep-widget --description 'Search by AST node, recursively, from current directory'
    __grep_widget \
        'AST pattern: ' \
        'ast-grep --pattern {q} --json=stream '$__directory_placeholder' | jq --raw-output \'"\(.file):\(.range.start.line + 1):\(.range.start.column + 1):\(.lines | gsub("\n"; "'(set_color bryellow)'␤'(set_color normal)'"))"\''
end
bind alt-a ast-grep-widget

function man-widget --description 'Search manpages'
    # This command turns 'manpage_name(section) - description' into 'section manpage_name'.
    # The `\s?` is there because macOS separates the name and section with a space.
    set parse_entry_command "string replace --regex -- '(?<name>^.*)\s?\((?<section>.*)\)\s+.*\$' '\$section \$name'"

    if not set choice ( \
        FZF_DEFAULT_COMMAND='man -k .' \
          fzf \
            --tiebreak=chunk,begin,end \
            --prompt 'manpages: ' \
            --preview "eval 'MANWIDTH=\$FZF_PREVIEW_COLUMNS man '($parse_entry_command {})" \
            --preview-window '75%' \
    )
        return
    end

    eval 'man '(eval "$parse_entry_command '$choice'")
end
abbr --add --global mw man-widget

function process-widget --description 'Manage processes'
    # I 'echo' the fzf placeholder in the grep regex to get around the fact that
    # fzf substitutions are single quoted and the quotes would mess up the grep
    # regex.
    if test (uname) = Linux
        set reload_command 'ps -e --format user,pid,ppid,nice=NICE,start_time,etime,command --sort=-start_time'
        set preview_command 'ps --pid {2} >/dev/null; or begin; echo "There is no running process with this ID."; exit; end; echo -s (set_color brblack) {} (set_color normal); pstree --hide-threads --long --show-pids --unicode --show-parents --arguments {2} | grep --color=always --extended-regexp --regexp "[^└|─]+,$(echo {2})( .*|\$)" --regexp "^"'
        set environment_flag e
        # Use 'sudo -v' so I'm not prompted for my password while strace is running,
        # since it will be running at the same time as fzf in a pipeline.
        set trace_command 'eval "$(if test (ps -o user= -p {2}) = root && not fish_is_root_user; echo "sudo -v; sudo "; end)""strace --summary --absolute-timestamps --attach={2}"'
    else
        set reload_command 'ps -e -o user,pid,ppid,nice=NICE,start,etime,command'
        # Using '-o pid' because without it I get the error:
        # time: requires entitlement
        set preview_command 'ps -p {2} -o pid >/dev/null; or begin; echo "There is no running process with this ID."; exit; end; echo -s (set_color brblack) {} (set_color normal); pstree -w -g 3 -p {2} | grep --color=always --extended-regexp --regexp " 0*$(echo {2}) $(echo {1}) .*" --regexp "^"'
        set environment_flag -E
        # TODO: Since dtruss doesn't exit upon receiving SIGPIPE, after I exit the
        # fzf viewer for the dtruss output, I have to hit ctrl-c again to get dtruss
        # to exit. I guess this is unavoidable since dtruss is a bash script and bash
        # is single threaded so it can't handle SIGPIPE until dtrace exits. I'd use
        # dtrace directly, which does respond to SIGPIPE, but getting it to print
        # system calls and all their arguments isn't trivial so I'd rather let dtruss
        # do that.
        #
        # Use 'sudo -v' so I'm not prompted for my password while dtruss is running,
        # since it will be running at the same time as fzf in a pipeline.
        set trace_command 'sudo -v; sudo -- dtruss -a -p {2}'
    end
    # TODO: The `string match` isn't perfect: if a variable's value
    # includes something that matches the environment variable name pattern
    # ([a-zA-Z_]+[a-zA-Z0-9_]*=), `string match` will consider that the start
    # of a new variable. For this reason we shouldn't change the order of the
    # variables e.g. sorting
    set environment_command 'eval "$(if test (ps -o user= -p {2}) = root && not fish_is_root_user; echo "sudo "; end)""ps '$environment_flag' -o command -ww {2}" | string match --groups-only --all --regex -- \' (?=([a-zA-Z_]+[a-zA-Z0-9_]*)=(.*?)(?: [a-zA-Z_]+[a-zA-Z0-9_]*=|$))\' | paste -d "=" - - | sed -e "s/\$/│/" | string replace "=" "=│" | '$PAGER' 0</dev/tty 1>/dev/tty 2>&1'

    if not set choice ( \
        FZF_DEFAULT_COMMAND="$reload_command" \
        FZF_HINTS='ctrl+alt+r: refresh process list\nctrl+alt+o: view process output\nctrl+alt+e: view environment variables (at the time the process was launched)\nctrl+alt+t: trace process system calls' \
        fzf \
            # only search on PID, PPID, and the command
            --nth '2,3,7..' \
            --bind "ctrl-alt-o:execute@process-output {2} 1>/dev/tty 2>&1 </dev/tty@,ctrl-alt-r:reload@$reload_command@+first,ctrl-alt-e:execute@$environment_command@,ctrl-alt-t:execute@$trace_command 2>&1 | fzf --no-sort --no-preview@" \
            --header-lines=1 \
            --prompt 'processes: ' \
            --preview "$preview_command" \
            --tiebreak=chunk,begin,end \
            --no-hscroll \
            --preview-window 'nowrap,75%' \
    )
        return
    end

    set process_ids (printf %s\n $choice | awk '{print $2}')
    set process_command_names (printf %s\n $choice | awk '{print $7}')
    for index in (seq (count $process_ids))
        set --append process_ids_names "$process_ids[$index] ($process_command_names[$index])"
    end

    if not set signal ( \
        FZF_DEFAULT_COMMAND="string split ' ' (kill -l)" \
        fzf \
            --header 'Select a signal to send or exit to print the PIDs' \
            --prompt 'signals: ' \
            --preview '' \
    )
        printf %s\n $process_ids
        return
    end

    echo "Sending SIG$signal to the following processes: $(string join ', ' $process_ids_names)"
    set sudo ''
    for process_id in $process_ids
        if test "$(ps -o user= -p $process_id)" = root && not fish_is_root_user
            set sudo sudo
            break
        end
    end
    fish -c "$sudo kill --signal $signal $process_ids"
end
abbr --add --global pw process-widget

function file-widget --description 'Search files'
    set dir (__widgets_get_directory_from_current_token)
    set prompt (__widgets_format_directory_for_prompt $dir)

    set preview_command '
        # TODO: timg cannot detect the line and column count of the screen in fzf
        if file --brief --mime-type {} | grep -q -i image
            if set --export --names | string match --quiet --regex \'^VSCODE_.*\'
                # TODO: timg should use iterm2 image mode for vscode
                timg -p iterm2 --center -g "$FZF_PREVIEW_COLUMNS"x"$FZF_PREVIEW_LINES" {}
            else
                timg --center -g "$FZF_PREVIEW_COLUMNS"x"$FZF_PREVIEW_LINES" {}
            end
        else
            bat --style=\'header-filename\' --color always --paging=never --terminal-width (math $FZF_PREVIEW_COLUMNS - 2) {}
        end
    '

    if not set choices ( \
        FZF_HINTS='alt+e: edit in neovim' \
        FZF_DEFAULT_COMMAND="test '$dir' = '.' && set _args '--strip-cwd-prefix' || set _args '.' $dir; fd \$_args --follow --hidden --type file --type symlink" \
        fzf \
            --prompt "$prompt" \
            --preview "$preview_command" \
            --preview-window '75%,~1' \
            --bind "alt-e:execute:nvim {1} </dev/tty >/dev/tty 2>&1" \
    )
        return
    end

    __widgets_replace_current_commandline_token $choices

    # this should be done whenever a binding produces output (see: man bind)
    commandline -f repaint
end
bind ctrl-f file-widget

function directory-widget --description 'Search directories'
    set dir (__widgets_get_directory_from_current_token)
    set prompt (__widgets_format_directory_for_prompt $dir)

    if not set choices ( \
        FZF_DEFAULT_COMMAND="test '$dir' = '.' && set _args '--strip-cwd-prefix' || set _args '.' $dir; fd \$_args --follow --hidden --type directory --type symlink" \
        fzf \
            --prompt "$prompt" \
            --preview 'echo -s (set_color brblack) "Directory: " {}; lsd --color always --hyperlink always {}' \
            --preview-window '75%,~1' \
            --keep-right \
    )
        return
    end

    __widgets_replace_current_commandline_token $choices

    commandline -f repaint
end
bind alt-d directory-widget

function history-widget --description 'Search history'
    # I'm using the NUL character to delimit history entries since they may span
    # multiple lines.
    if not set choices ( \
        FZF_DEFAULT_COMMAND="history --null" \
        fzf \
        --prompt 'history: ' \
        --no-preview \
        --scheme history \
        --no-hscroll \
        --read0 \
        --print0 \
        --query (commandline) \
        | string split0 \
    )
        return
    end

    commandline --replace -- $choices
end
# The script in conf.d for the plugin 'jorgebucaran/autopair.fish' is deleting
# my ctrl+h keybind that I define in here. As a workaround, I set this keybind
# when the first prompt is loaded which should be after autopair is loaded.
function __set_fzf_history_keybind --on-event fish_prompt
    # I only want this to run once so delete the function.
    functions -e (status current-function)
    bind ctrl-h history-widget
end
