if not status is-interactive
    exit
end

# TODO: I should scan the completion commands for this string and escape it in some
# way to guarantee that there is never a collision.
set --export COMPLETION_SYNC_ENTRIES_DELIMITER ':::::::completion_sync:::::::'

if not set --query --export COMPLETION_SYNC_ADDITION_FILES COMPLETION_SYNC_ADDITION_ENTRIES_FILE
    set --export COMPLETION_SYNC_ADDITION_FILES
    set --export COMPLETION_SYNC_ADDITION_ENTRIES_FILE (mktemp)
end
if not set --query --global COMPLETION_SYNC_ADDITION_ENTRIES
    # The autocomplete entries for `ruff` exceeded the max length of an environment
    # variable so a file has to be used.
    set --global COMPLETION_SYNC_ADDITION_ENTRIES "$(cat $COMPLETION_SYNC_ADDITION_ENTRIES_FILE)"
end

if not set --query --export COMPLETION_SYNC_PID
    set --export COMPLETION_SYNC_PID $fish_pid
end

function _completion_sync_debug --argument-names message
    if test -n "$COMPLETION_SYNC_DEBUG"
        echo "[completion-sync] $message" >&2
    end
end

function _completion_sync_list
    string split --no-empty ':' "$COMPLETION_SYNC_ADDITION_FILES"
end

function _completion_sync_add --argument-names file
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
        return
    end

    if test -n "$COMPLETION_SYNC_ADDITION_FILES"
        set COMPLETION_SYNC_ADDITION_FILES "$COMPLETION_SYNC_ADDITION_FILES:"
    end
    set COMPLETION_SYNC_ADDITION_FILES "$COMPLETION_SYNC_ADDITION_FILES$file"

    if test -n "$COMPLETION_SYNC_ADDITION_ENTRIES"
        set COMPLETION_SYNC_ADDITION_ENTRIES "$COMPLETION_SYNC_ADDITION_ENTRIES$COMPLETION_SYNC_ENTRIES_DELIMITER"
    end
    set COMPLETION_SYNC_ADDITION_ENTRIES "$COMPLETION_SYNC_ADDITION_ENTRIES""$(string join --no-empty \n $added_entries)"
    set _completion_sync_should_update_file true
end

function _completion_sync_remove --argument-names file
    set -l files (_completion_sync_list)
    set -l entries (string split --no-empty $COMPLETION_SYNC_ENTRIES_DELIMITER "$COMPLETION_SYNC_ADDITION_ENTRIES")

    set -l file_index (contains --index -- $file $files)

    set --erase files[$file_index]
    set COMPLETION_SYNC_ADDITION_FILES "$(string join ':' $files)"

    set -l added_entries (string split --no-empty \n "$entries[$file_index]")
    set -l command (path change-extension '' (path basename $file))
    set -l current_entries (complete $command)
    for entry in $added_entries
        if set -l entry_index (contains --index -- $entry $current_entries)
            set --erase current_entries[$entry_index]
        end
    end
    complete --erase $command
    printf %s\n $current_entries | source

    set --erase entries[$file_index]
    set COMPLETION_SYNC_ADDITION_ENTRIES "$(string join $COMPLETION_SYNC_ENTRIES_DELIMITER $entries)"
    set _completion_sync_should_update_file true
end

function _completion_sync
    set --global _completion_sync_should_update_file false

    if test $COMPLETION_SYNC_PID != $fish_pid
        _completion_sync_debug 'A sub shell was started, resetting state...'

        # On startup, Fish will add XDG_DATA_DIRS to fish_complete_path so we'll
        # remove the ones we're managing.
        #
        # If we ever change our minds and decide to leave them, we need to remove the
        # code further down that ignores files that are already in
        # fish_complete_path.
        for addition_file in (_completion_sync_list)
            if set -l index (contains --index -- (path dirname $addition_file) $fish_complete_path)
                set --erase fish_complete_path[$index]
            end
        end

        set COMPLETION_SYNC_PID $fish_pid

        # Reset completion state since we're in a subshell
        set COMPLETION_SYNC_ADDITION_FILES
        set COMPLETION_SYNC_ADDITION_ENTRIES
        set _completion_sync_should_update_file true
    end

    _completion_sync_debug 'Syncing...'

    set -l xdg_files
    for dir in (string split --no-empty ":" "$XDG_DATA_DIRS")
        set dir $dir'/fish/vendor_completions.d'
        if not test -d $dir
            continue
        end
        if contains $dir $fish_complete_path
            continue
        end

        for file in $dir/*
            set --append xdg_files $file
        end
    end
    if test (count $xdg_files) -gt 0
        _completion_sync_debug 'Completion files found in XDG_DATA_DIRS:'\n"$(string join \n $xdg_files)"
    end

    set -l addition_files (_completion_sync_list)

    # Remove whatever is in additions, but not xdg
    set -l removed files
    for addition_file in $addition_files
        if not contains $addition_file $xdg_files
            _completion_sync_remove $addition_file
            set --append removed_files $addition_file
        end
    end
    if test (count $removed_files) -gt 0
        _completion_sync_debug 'Removing completions for these files:'\n"$(string join \n $removed_files)"
    end

    # Add whatever is in xdg, but not additions
    set -l added_files
    for xdg_file in $xdg_files
        if not contains $xdg_file $addition_files
            _completion_sync_add $xdg_file
            set --append added_files $xdg_file
        end
    end
    if test (count $added_files) -gt 0
        _completion_sync_debug 'Adding completions for these files:'\n"$(string join \n $added_files)"
    end

    if test $_completion_sync_should_update_file = true
        printf %s "$COMPLETION_SYNC_ADDITION_ENTRIES" >$COMPLETION_SYNC_ADDITION_ENTRIES_FILE
    end
end

# Run after direnv's prompt hook
function _completions_sync_register --on-event fish_prompt
    functions --erase (status current-function)

    functions --copy __direnv_export_eval __direnv_export_eval_backup
    function __direnv_export_eval --on-event fish_prompt
        __direnv_export_eval_backup
        _completion_sync
    end

    # In case direnv's hook hasn't run yet, run it now
    __direnv_export_eval
end
