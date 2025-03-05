if not status is-interactive
    exit
end

if test (uname) != Linux
    exit
end

abbr --add --global pipr 'pipr --no-isolation'
bind ctrl-p pipr-widget

function pipr-widget
    set -l commandline (commandline -b)
    set -l result (pipr --no-isolation --default "$commandline")
    commandline --replace $result
    commandline -f repaint
end
