if not status is-interactive
    exit
end

set -x COMPLETE_FISH_DEBUG 1
function _complete_fish_debug --argument-names message
    if test -n "$COMPLETE_FISH_DEBUG"
        echo "[completion-sync] $message" >&2
    end
end

function _complete_fish_remove_managed_files_from_complete_path
    set -l removed_paths
    for addition_file in $_complete_fish_files
        if set -l index (contains --index -- (path dirname $addition_file) $fish_complete_path)
            set --append removed_paths $fish_complete_path[$index]
            set --erase fish_complete_path[$index]
        end
    end
    if test (count $removed_paths) -gt 0
        _complete_fish_debug 'Paths removed from fish_complete_path:'\n"$(string join \n $removed_paths)"
    end
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

        if set --query --global _complete_fish_files
            set --append _complete_fish_files $file
        else
            set --global _complete_fish_files $file
        end

        set -l added_entries_string "$(string join --no-empty \n $added_entries)"
        # The autocomplete entries for `ruff` exceeded the max length of an
        # environment variable so a global variable should be used.
        if set --query --global _complete_fish_entries
            set --append _complete_fish_entries $added_entries_string
        else
            set --global _complete_fish_entries $added_entries_string
        end
    end
end

function _complete_fish_convert_xdg_to_path_variable
    # TODO: On Linux, fish treats XDG_DATA_DIRS like a "path variable", meaning
    # its value is split on ":". However, on macOS it's a single element. I
    # think they should do the same thing on either platform.
    set --path XDG_DATA_DIRS "$XDG_DATA_DIRS"
end

function _complete_fish_post_load
    _complete_fish_debug 'In post load'

    _complete_fish_convert_xdg_to_path_variable

    set -l xdg_files
    for dir in $XDG_DATA_DIRS
        # This was in XDG before direnv was loaded so ignore it
        if contains $dir $COMPLETE_FISH_OLD_XDG_PATH
            continue
        end

        set -l fish_dir $dir'/fish/vendor_completions.d'
        if not test -d $fish_dir
            continue
        end
        set --append xdg_files $fish_dir/*
    end
    if test (count $xdg_files) -eq 0
        return
    end

    _complete_fish_debug 'Adding completions for these files:'\n"$(string join \n $xdg_files)"
    _complete_fish_add $xdg_files

    # On startup, Fish will add XDG_DATA_DIRS to fish_complete_path so we'll
    # remove the ones we're managing.
    #
    # Cases where we need to do this:
    #   - A sub shell is started in a direnv environment
    #   - `exec` is used in a direnv environment
    #
    # TODO: I should only be doing this if we're in one of the cases above, but
    # I think it's safe to just always do it.
    _complete_fish_remove_managed_files_from_complete_path
end

function _complete_fish_post_unload
    _complete_fish_debug 'In post unload'

    _complete_fish_convert_xdg_to_path_variable

    if test (count $_complete_fish_files) -eq 0
        return
    end

    _complete_fish_debug 'Removing completions for these files:'\n"$(string join \n $_complete_fish_files)"

    for file_index in (seq (count $_complete_fish_files))
        set -l added_entries (string split --no-empty \n "$_complete_fish_entries[$file_index]")
        set -l file $_complete_fish_files[$file_index]
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
    set _complete_fish_files
    set _complete_fish_entries
end

function _complete_fish_pre_load
    _complete_fish_debug 'In pre load'

    _complete_fish_convert_xdg_to_path_variable

    # This variable holds the value of XDG_DATA_DIRS before the direnv environment is
    # loaded. It's exported to account for the following edge cases:
    #   - A sub shell is started in a direnv environment: The XDG_DATA_DIRS in the
    #     sub shell will contain everything that direnv adds to it.
    #   - `exec` is used in a direnv environment: The XDG_DATA_DIRS in the new
    #     process will contain everything that direnv adds to it.
    #   - The user moves from one direnv environment directly to another direnv
    #     environment: XDG_DATA_DIRS will contain everything the old direnv
    #     environment added to it. This is a limitation of how I call the pre_load
    #     hook. There is a comment where _complete_fish_pre_load is called with
    #     details on the limitation.
    #
    # It needs to end in 'PATH' so fish can treat it like an array, but join it with
    # ':' when exported.
    if not set --query --global --export COMPLETE_FISH_OLD_XDG_PATH
        set --global --export COMPLETE_FISH_OLD_XDG_PATH $XDG_DATA_DIRS
    end
end

function _complete_fish_nearest_envrc
    set -l current_directory (pwd)
    while true
        if test -e $current_directory/.envrc
            echo $current_directory/.envrc
            return
        end

        set -l parent_directory $current_directory/..
        # This will happen when we hit the root directory e.g. '/'
        if test $current_directory -ef $parent_directory
            return
        end
        set current_directory $parent_directory
    end
end

function _complete_fish_is_moving_directly_to_new_direnv
    if not set --query DIRENV_DIR
        echo false
        return
    end

    set -l nearest_envrc "$(_complete_fish_nearest_envrc)"
    if test -z "$nearest_envrc"
        echo false
        return
    end

    # DIRENV_DIR starts with a '-', the `string sub` removes it
    set -l direnv_dir (string sub --start 2 -- $DIRENV_DIR)
    if test (path resolve (path dirname $nearest_envrc)) != (path resolve $direnv_dir)
        echo true
        return
    end

    echo false
end

# Replace direnv's prompt hook with one that will call our pre and post hooks.
function _complete_fish_register --on-event fish_prompt
    functions --erase (status current-function)

    functions --copy __direnv_export_eval __direnv_export_eval_backup
    function __direnv_export_eval --on-event fish_prompt
        set -l is_moving_directly_to_new_direnv (_complete_fish_is_moving_directly_to_new_direnv)

        # Determine which pre hooks should run
        set -l nearest_envrc "$(_complete_fish_nearest_envrc)"
        if test -n "$nearest_envrc"
            if not set --query DIRENV_DIR
                _complete_fish_pre_load
            else
                if not set --query --global _complete_fish_direnv_loaded
                    # If DIRENV_DIR is set, but _complete_fish_direnv_loaded
                    # isn't, then the user either called `exec fish` or started
                    # a sub shell. Doing either of those would erase global
                    # variables, like _complete_fish_direnv_loaded, but not
                    # DIRENV_DIR.
                    _complete_fish_pre_load
                else if test $is_moving_directly_to_new_direnv = true
                    # TODO: I want to call this after the old direnv is unloaded and
                    # before the new direnv is loaded, but direnv does them both in its
                    # single hook.
                    _complete_fish_pre_load
                end
            end
        end

        __direnv_export_eval_backup

        # Determine which post hooks should run
        if not set --query --global _complete_fish_direnv_loaded
            and set --query DIRENV_DIR

            set --global _complete_fish_direnv_loaded true
            _complete_fish_post_load
        else if set --query --global _complete_fish_direnv_loaded
            and not set --query DIRENV_DIR

            set --erase _complete_fish_direnv_loaded
            _complete_fish_post_unload
        else if test $is_moving_directly_to_new_direnv = true
            # TODO: I want to call this after the old direnv is unloaded and
            # before the new direnv is loaded, but direnv does them both in its
            # single hook.
            _complete_fish_post_unload

            _complete_fish_post_load
        end
    end

    __direnv_export_eval
end
