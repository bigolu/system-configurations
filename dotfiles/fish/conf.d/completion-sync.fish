if not status is-interactive
    exit
end

set -x COMPLETION_SYNC_DEBUG 1
function _complete_fish_debug --argument-names message
    if test -n "$COMPLETION_SYNC_DEBUG"
        echo "[completion-sync] $message" >&2
    end
end

function _complete_fish_remove_managed_files_from_complete_path
    set -l removed_paths
    for addition_file in $COMPLETE_FISH_PATH
        if set -l index (contains --index -- (path dirname $addition_file) $fish_complete_path)
            set --append removed_paths $fish_complete_path[$index]
            set --erase fish_complete_path[$index]
        end
    end
    if test (count $removed_paths) -gt 0
        _complete_fish_debug 'Paths removed from fish_complete_path:'\n"$(string join \n $removed_paths)"
    end

    set --erase COMPLETE_FISH_PATH
end

function _complete_fish_add
    for file in $argv
        set -l command (path change-extension '' (path basename $file))

        set -l old_entries (complete $command)
        source $file
        set -l new_entries (complete $command)
        set -l added_entries
        for new_entry in $new_entries
            if not contains $new_entry $old_entries
                set --append added_entries $new_entry
            end
        end
        if test (count $added_entries) -eq 0
            _complete_fish_debug "This file didn't add any completion entries, ignoring: $file"
            return
        end

        # Fish will treat variables with 'PATH' suffix like arrays, but when
        # exported the elements will be joined by ':'.
        #
        # This needs to be exported for
        # `_complete_fish_remove_managed_files_from_complete_path` to work.
        if set --query --export COMPLETE_FISH_PATH
            set --append COMPLETE_FISH_PATH $file
        else
            set --global --export COMPLETE_FISH_PATH $file
        end

        set -l added_entries_string "$(string join --no-empty \n $added_entries)"
        # The autocomplete entries for `ruff` exceeded the max length of an
        # environment variable so a global variable should be used.
        if set --query --global COMPLETE_FISH_ENTRIES
            set --append COMPLETE_FISH_ENTRIES $added_entries_string
        else
            set --global COMPLETE_FISH_ENTRIES $added_entries_string
        end
    end
end

function _complete_fish_remove
    for file_index in (seq (count $COMPLETE_FISH_PATH))
        set -l added_entries (string split --no-empty \n "$COMPLETE_FISH_ENTRIES[$file_index]")
        set -l file $COMPLETE_FISH_PATH[$file_index]
        set -l command (path change-extension '' (path basename $file))
        set -l current_entries (complete $command)
        for entry in $added_entries
            if set -l entry_index (contains --index -- $entry $current_entries)
                set --erase current_entries[$entry_index]
            end
        end
        complete --erase $command
        printf %s\n $current_entries | source
    end
    set COMPLETE_FISH_PATH
    set COMPLETE_FISH_ENTRIES
end

function _complete_fish_post_load
    _complete_fish_debug 'In post load'

    # On startup, Fish will add XDG_DATA_DIRS to fish_complete_path so we'll
    # remove the ones we're managing.
    #
    # Cases where we need to do this:
    #   - A sub shell is started in a direnv environment
    #   - `exec` is used in a direnv environment
    #
    # I'm not sure how to detect all of these cases so I'll just always do it.
    #
    # If we ever change our minds and decide to leave them, we need to
    # remove the code further down that ignores files that are already in
    # fish_complete_path.
    _complete_fish_remove_managed_files_from_complete_path

    set -l xdg_files
    for dir in $XDG_DATA_DIRS
        set dir $dir'/fish/vendor_completions.d'

        if not test -d $dir
            continue
        end

        # We only want to add completions for directories added to XDG
        # by direnv. I'm not sure how to do that without a 'pre-load'
        # hook. Instead, we'll ignore directories that are already in
        # `fish_complete_path`. Fish adds those on startup.
        if contains $dir $fish_complete_path
            continue
        end

        set --append xdg_files $dir/*
    end
    if test (count $xdg_files) -eq 0
        return
    end

    _complete_fish_debug 'Adding completions for these files:'\n"$(string join \n $xdg_files)"
    _complete_fish_add $xdg_files
end

function _complete_fish_pre_unload
    _complete_fish_debug 'In pre unload'

    if test (count $COMPLETE_FISH_PATH) -eq 0
        return
    end

    _complete_fish_debug 'Removing completions for these files:'\n"$(string join \n $COMPLETE_FISH_PATH)"
    _complete_fish_remove
end

function _complete_fish_main
    if not set --query --global COMPLETE_FISH_DIRENV_LOADED
        and set --query DIRENV_DIR

        set --global COMPLETE_FISH_DIRENV_LOADED true
        _complete_fish_post_load
    else if set --query --global COMPLETE_FISH_DIRENV_LOADED
        and not set --query DIRENV_DIR

        set --erase COMPLETE_FISH_DIRENV_LOADED
        _complete_fish_pre_unload
    end
end

# Run after direnv's prompt hook
function _complete_fish_register --on-event fish_prompt
    functions --erase (status current-function)

    functions --copy __direnv_export_eval __direnv_export_eval_backup
    function __direnv_export_eval --on-event fish_prompt
        __direnv_export_eval_backup
        _complete_fish_main
    end

    # In case direnv's hook hasn't run yet, run it now
    __direnv_export_eval
end
