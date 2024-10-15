if not status is-interactive
    exit
end

abbr --add --global g git
abbr --add --global x 'chmod +x'
abbr --add --global du 'du --dereference --human-readable --summarize --apparent-size'
set --global --export MANOPT --no-hyphenation
function timg --wraps timg
    set options
    if test "$TERM_PROGRAM" = WezTerm
        # TODO: timg should use iterm2 image mode for WezTerm
        #
        # TODO: switch to kitty when wezterm gets support:
        # https://github.com/wez/wezterm/issues/986
        set options -p iterm2
    else if set --export --names | string match --quiet --regex '^VSCODE_.*'
        # TODO: timg should use iterm2 image mode for vscode
        set options -p iterm2
    end
    command timg --center $options $argv
end
if test (uname) = Linux
    abbr --add --global initramfs-reload 'sudo update-initramfs -u -k all'
    abbr --add --global logout-all 'sudo killall -u $USER'
    abbr --add --global icon-reload 'sudo update-icon-caches /usr/share/icons/* ~/.local/share/icons/*'
    # reload the database used to search for applications
    abbr --add --global desktop-entry-reload 'sudo update-desktop-database; update-desktop-database ~/.local/share/applications'
    abbr --add --global ruhroh 'sudo truncate -s 0 /var/log/syslog'
    abbr --add --global font-reload 'fc-cache -vr'
    abbr --add --global open xdg-open
    abbr --add --position anywhere --global pbpaste fish_clipboard_paste
    # autocomplete doesn't work unless "put" is used, even though just 'trash'
    # is an alias for 'trash put'
    abbr --add --position anywhere --global trash 'trash put'
end

# page
# lesspipe needs this set for syntax highlighting
set --global --export LESSOPEN '|lesspipe.sh %s'
set --global --export PAGER page
function page --wraps page
    less $argv | command page
end

# Set preferred editor. Programs check either of these variables for the
# preferred editor so I'll set both.  For more information on the meaning of
# these variables, see:
# https://unix.stackexchange.com/questions/4859/visual-vs-editor-what-s-the-difference/302391#302391
begin
    set --local editor
    if set --export --names | string match --quiet --regex '^VSCODE_.*'
        set editor code --reuse-window --wait
    else
        set editor nvim
    end
    set --global --export VISUAL "$(command -v $editor[1]) $editor[2..]"
    set --global --export EDITOR $VISUAL
end
if test (uname) = Darwin
    abbr --add --global -- sudoedit 'sudo --edit'
end
abbr --add --global -- vim nvim

# Change the color grep uses for highlighting matches to magenta
set --global --export GREP_COLORS 'ms=00;35'

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
set --global --export LS_COLORS 'di=0:ln=37:so=37:pi=37:ex=37:bd=37:cd=37:su=37:sg=37:tw=37:ow=37:or=31:mi=31:no=37:*=37'

# cd
abbr --add --global -- - 'cd -'

# python
# Don't add the name of the virtual environment to my prompt. This way, I can
# add it myself using the same formatting as the rest of my prompt.
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

# direnv
set --global --export DIRENV_LOG_FORMAT \n(set_color brblack)'┃ direnv: %s'(set_color normal)
set -g direnv_fish_mode disable_arrow # trigger direnv at prompt only

# vscode
# Clearing SHELL because my config for the OS default shell only launches fish
# if the current shell isn't fish.
abbr --add --global code 'SHELL= code'

# ulimit
#
# Increase maxixmum number of open file descriptors that a single process can
# have. This applies to the current process and its descendents.
ulimit -Sn 10000

# comma
function , --wraps ,
    # The `--with-nth` to remove the '.out' extension from the entries.
    FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --separator '' --height 10 --margin 0,2,0,2 --preview-window right,75%,border-left --preview 'nix-search --details --max-results 1 --name (string sub --end -4 {})' --delimiter '.' --with-nth '..-5'" COMMA_PICKER=fzf command , $argv
end

# touch
function touchx
    set filename "$argv"
    touch "$filename"
    chmod +x "$filename"
end
function touchp --description 'Create file and make parent directories' --argument-names filepath
    set -l parent_folder (dirname $filepath)
    mkdir -p $parent_folder
    touch $filepath
end

# Launch a program and detach from it. Meaning it will be disowned and its
# output will be suppressed
#
# TODO: Have it wrap sudo so it autocompletes program names.  I should write my
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
        --mount ~/.cloudflared/a52a24f6-92ee-4dc5-b537-24bad84b7b1f.json \
        --mount-template (echo '{{.CLOUDFLARED_TUNNEL}}' | psub) \
        --mount-max-reads 1 -- \
        cloudflared tunnel run --url "http://localhost:$port"
end

function rust --description 'run the given rust source file' --wraps rustc
    if test (count $argv) -eq 0
        echo -s \
            (set_color red) \
            'ERROR: You must provide at least one argument, the source file to run' >/dev/stderr
        return 1
    end

    set source_file $argv[-1]
    set executable_name (basename $source_file .rs)
    rustc $argv
    and begin
        ./$executable_name
        rm $executable_name
    end
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
abbr --add --global watch 'watch --no-title --differences --interval 1s'

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
    br -w $argv
end
abbr --add --global tree broot

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
        diffoscope --text-color always $argv | page
    else
        diffoscope --text-color always $argv
    end
end
