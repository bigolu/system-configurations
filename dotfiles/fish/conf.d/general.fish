if not status is-interactive
    exit
end

abbr --add --global x 'chmod +x'
abbr --add --global du 'du --dereference --human-readable --summarize --apparent-size'
function timg --wraps timg
    command timg --center $argv
end
if test (uname) = Linux
    abbr --add --global initramfs-reload 'sudo update-initramfs -u -k all'
    abbr --add --global logout-all 'sudo killall -u $USER'
    abbr --add --global clear-syslog 'sudo truncate -s 0 /var/log/syslog'
    abbr --add --position anywhere --global pbpaste fish_clipboard_paste
    abbr --add --position anywhere --global pbcopy fish_clipboard_copy
    abbr --add --global trash 'trash put'
end

# less
# This isn't in the portable home
if type --query lesspipe.sh
    set --global --export LESSOPEN '|lesspipe.sh %s'
end
set --global --export PAGER less
# TODO: lesspipe requires this to be set to enable syntax highlighting. I should open
# an issue to have it read lesskey
set --global --export LESS -R
# Have lesspipe use bat for syntax highlighting
set --global --export LESSCOLORIZER bat
abbr --add --position anywhere --global page less

# man
set --global --export MANOPT --no-hyphenation

# Set preferred editor. Programs check either of these variables for the
# preferred editor so I'll set both. For more information on the meaning of
# these variables, see:
# https://unix.stackexchange.com/questions/4859/visual-vs-editor-what-s-the-difference/302391#302391
begin
    set --local editor_arguments nvim
    set --local joined_editor_arguments (string join ' ' -- (type --force-path $editor_arguments[1]) $editor_arguments[2..])
    set --global --export VISUAL "$joined_editor_arguments"
    set --global --export EDITOR $VISUAL
end
abbr --add --global -- vim nvim

set --global --export GREP_COLORS 'ms=00;36'

# ls
# use the long format
abbr --add --position anywhere --global ll 'ls -l'
# Add colors for files types that aren't already given an icon by `ls
# --classify` e.g. broken symlinks.
#
# File types:
# [bd]="block device"
# [ca]="file with capability"
# [cd]="character device"
# [di]="directory"
# [do]="door"
# [ex]="executable file"
# [fi]="regular file"
# [ln]="symbolic link"
# [mh]="multi-hardlink"
# [mi]="missing file"
# [no]="normal non-filename text"
# [or]="orphan symlink"
# [ow]="other-writable directory"
# [pi]="named pipe, AKA FIFO"
# [rs]="reset to no color"
# [sg]="set-group-ID"
# [so]="socket"
# [st]="sticky directory"
# [su]="set-user-ID"
# [tw]="sticky and other-writable directory"
# From: https://askubuntu.com/a/884513/1497983
set --global --export LS_COLORS 'di=0:ln=37:so=37:pi=37:ex=37:bd=37:cd=37:su=37:sg=37:tw=37:ow=37:or=31:mi=31:no=37:st=37:*=37'

# cd
abbr --add --global -- - 'cd -'

# python
#
# Don't add the name of the virtual environment to my prompt. This way, I can add it
# myself using the same formatting as the rest of my prompt.
set --global --export VIRTUAL_ENV_DISABLE_PROMPT 1
function python --wraps python
    if not type --no-functions --query python
        echo (set_color red)'error'(set_color normal)': python was not found on the PATH' >&2
        return 1
    end

    # Check if python is being run interactively
    if test (count $argv) -eq 0
        or contains -- -i $argv
        # Check if python has the ipython package installed
        #
        # If I pipe the output of python to grep, python will raise a
        # BrokenPipeError. To avoid this, I use echo to pipe the output.
        if echo (command python -m pip list) | string match --quiet --regex ipython
            python -m IPython
            return
        end
    end
    command python $argv
end

# zoxide
set --global --export _ZO_FZF_OPTS "$FZF_DEFAULT_OPTS --preview 'lsd --color always --hyperlink always {2}' --keep-right --tiebreak index"
# This needs to run after the zoxide.fish config file or I get an infinite loop
# so I run it when the fish_prompt event fires.
function __create_cd_function --on-event fish_prompt
    # I only want this to run once so delete the function.
    functions -e (status current-function)

    alias cd __zoxide_z
    alias cdh __zoxide_zi
end

# vscode
#
# Clear SHELL because my config for the OS default shell only launches fish if the current
# shell isn't fish.
function code --wraps code
    SHELL= command code $argv
end

# ulimit
#
# Increase maxixmum number of open file descriptors that a single process can
# have. This applies to the current process and its descendents.
ulimit -Sn 10000

# comma
function , --wraps ,
    # `--with-nth` removes the '.out' extension from the entries.
    FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --separator '' --height 10 --margin 0,2,0,2 --preview-window right,75%,border-left --preview 'nix-search --details --max-results 1 --name (string sub --end -4 {})' --delimiter '.out' --with-nth '{1}'" COMMA_PICKER=fzf command , $argv
end

# touch
function touchx
    set filename "$argv"
    touch "$filename"
    chmod +x "$filename"
end
function touchp --description 'Create file and make parent directories' --argument-names filepath
    set -l parent_folder (path dirname $filepath)
    mkdir -p $parent_folder
    touch $filepath
end

# Launch a program and detach from it. Meaning it will be disowned and its
# output will be suppressed
#
# TODO: Have it wrap sudo so it autocompletes program names. I should write my
# own completion script though since this will also autocomplete sudo flags.
function detach --wraps sudo
    # Redirecting the i/o files on the command itself still resulted in some
    # output being sent to the terminal, but putting the command in a block and
    # redirecting the i/o files of the block does the trick.
    begin
        $argv & disown
    end >/dev/null 2>/dev/null </dev/null
end

function tunnel --description 'Connect my cloudflare tunnel to the specified port on localhost' --argument-names port
    if test (count $argv) -eq 0
        set function_name (status current-function)
        echo -s \
            (set_color red) \
            "ERROR: You need to specify a port, e.g. '$function_name 8000'" >/dev/stderr
        return 1
    end
    doppler run \
        --mount ~/.cloudflared/2c881c12-5fd8-4f5e-a2f4-f692af8abffa.json \
        --mount-template (echo '{{.CLOUDFLARED_TUNNEL}}' | psub) \
        --mount-max-reads 1 -- \
        cloudflared tunnel run --url "http://localhost:$port"
end

function ls --wraps lsd
    lsd $argv
end

# Wrapping watch since viddy doesn't have autocomplete:
# https://github.com/sachaos/viddy/issues/73
#
# The function has options I always want enabled, the abbreviation has options I
# may want to tweak interactively.
function watch --wraps watch
    viddy --disable_auto_save $argv
end
# watch
abbr --add --global watch 'watch --no-title --differences --interval 1s --exec'

function sh --wraps yash
    if type --query yash
        yash $argv
    else
        command sh $argv
    end
end

abbr --add --global chase 'chase --verbose'

# broot
function dui --wraps broot --description 'Check disk usage interactively'
    br --whale-spotting $argv
end
abbr --add --global t broot --cmd ':toggle_preview'
abbr --add --global tl broot --sizes --dates --permissions

# diffoscope
function diff-html
    set temp (mktemp --suffix .html)
    diffoscope \
        --html "$temp" \
        --jquery 'https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js' \
        $argv
    open "$temp"
end
function diff
    if isatty 1
        diffoscope --text-color always $argv | "$PAGER"
    else
        diffoscope --text-color always $argv
    end
end

# ripgrep
set xdg_config (test -n "$XDG_CONFIG_HOME" && echo $XDG_CONFIG_HOME || echo "$HOME/.config")
set --export RIPGREP_CONFIG_PATH "$xdg_config/ripgrep/ripgreprc"

# sudo
if test (uname) = Darwin
    abbr --add --global -- sudoedit 'sudo --edit'
end
function elevate
    sudo -- (type --force-path run-as-admin) sudo --preserve-env=PATH,SHLVL,HOME --shell
end

# Task runner
function _task_runner
    if type --query mise
        echo 'mise run'
    else if type --query just
        echo just
    else
        return 1
    end
end
abbr --add --global run --function _task_runner

# git
abbr --add --global g git
# TODO: My pre-commit hook doesn't run if I use an alias for 'commit'. Not sure if
# that's a bug in git.
abbr --command git c commit
abbr --command git ca add -A '&&' git commit
