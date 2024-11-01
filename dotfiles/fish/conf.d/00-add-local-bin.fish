if not status is-interactive
    exit
end

function __add_local_bin --on-event fish_prompt
    functions --erase (status current-function)
    # macOS doesn't set this
    fish_add_path --global --prepend --move "$HOME/.local/bin"
end
