if not status is-interactive
    exit
end

# direnv autocomplete shell hook
# ------------------------------------------------------------------------------
# This hook will load autocomplete scripts from any directories added to
# XDG_DATA_DIRS by direnv.
#
# How it works:
# TODO

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
    set --erase _complete_fish_files
    set --erase _complete_fish_entries

    set --erase COMPLETE_FISH_OLD_XDG_PATH
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

function _complete_fish_pre_unload
    # This isn't needed for completion sync, but I'm including it just to complete
    # the illustration of how shell hooks could be implemented in direnv.
    :
end

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

# direnv hook wrapper
# ------------------------------------------------------------------------------
# This wrapper is responsible for calling the pre and post hooks. There are four
# hooks:
#   - pre_load: This is useful for recording what an environment variable contained
#     before loading direnv.
#   - pre_unload: You can use this to undo the shell-specific changes.
#   - post_load: This is where you should apply the shell-specific changes.
#   - post_unload: You can use this to undo the shell-specific changes.
#
# This next section will describe the actions that lead to each hook being run.
#   Actions:
#     - cd: Change directory
#     - exec: Running `exec fish`
#     - sub_shell Running `fish`
#   Terminology:
#     - direnv: A directory that itself, or one of its ancestors, contains a .envrc.
#     - non_direnv: A directory that itself, or one of its ancestors, does not
#       contain a .envrc.
#   When hooks are called:
#     1. cd from non_direnv to allowed direnv: pre_load runs before direnv loads.
#        post_load runs after direnv loads.
#     2. cd from allowed direnv to non_direnv: pre_unload runs before direnv is
#        unloaded. post_unload runs after direnv is unloaded.
#     3. cd from allowed direnv1 to allowed direnv2: pre_unload runs before direnv1 is unloaded.
#        post_unload runs after direnv1 is unloaded. pre_load runs before direnv2 is
#        loaded. post_load runs after direnv2 is loaded.
#        LIMITATIONS: pre_load should be called after direnv1 is unloaded, but it's
#        called while direnv1 is still loaded. post_unload should be called before
#        direnv2 is loaded, but it's called afterwards.
#     4. exec while inside an allowed direnv: pre_load runs before direnv is loaded. post_load
#        runs after direnv is loaded.
#        LIMITATIONS: pre_load should be called before direnv is loaded, but since
#        exec is used, the new process will inherit the environment variables set by
#        direnv in the old process.
#     5. sub_shell while inside an allowed direnv: pre_load runs before direnv is loaded.
#        post_load runs after direnv is loaded.
#        LIMITATIONS: pre_load should be called before direnv is loaded, but the
#        child process will inherit the environment variables set by direnv in the
#        parent process.
#     6. One of the watched files changes in an allowed direnv and direnv reloads:
#        pre_unload runs before the old direnv is unloaded. post_unload runs after
#        the old direnv is unloaded. pre_load runs before the new direnv is loaded.
#        post_load runs after the new direnv is loaded.
#        LIMITATIONS: This case is currently not being handled.
#     7. User runs `direnv block` within an allowed direnv: pre_unload runs before
#        direnv is unloaded. post_unload runs after direnv is unloaded.
#        LIMITATIONS: This case is currently not being handled.
#     8. User runs `direnv allow` within a blocked direnv: pre_load runs before
#        direnv is loaded. post_load runs after direnv is loaded.
#        LIMITATIONS: This case is currently not being handled.
#     9. cd from allowed direnv to blocked direnv: pre_unload runs before allowed
#        direnv is unloaded. post_unload runs after allowed direnv is unloaded.
#        LIMITATIONS: This currently has the same behavior as case #3, but it
#        shouldn't.
#    10. User closes the shell or terminal: pre_unload is run. This could be useful
#        for a shell hook that starts servers in the background.
#        LIMITATIONS: This case is currently not being handled.

# Replace direnv's prompt hook with one that will call our pre and post hooks.
#
# TODO: For this to work correctly, this file must be loaded before direnv's config
# runs. This way, the function below will run before `__direnv_export_eval` and we
# can wrap it before it gets a chance to run. This works on my machine since this
# file starts with a 'c' and direnv's config is in a file named 'direnv.fish'. I
# should find a way to guarantee that this runs at the right time.
function _complete_fish_register_direnv_hook_wrapper --on-event fish_prompt
    functions --erase (status current-function)

    if not type --query __direnv_export_eval
        return
    end

    functions --copy __direnv_export_eval __direnv_export_eval_backup
    function __direnv_export_eval --on-event fish_prompt
        set -l is_moving_from_one_direnv_directly_to_another \
            (_complete_fish_is_moving_from_one_direnv_directly_to_another)

        # Determine which pre hooks should run
        set -l nearest_envrc "$(_complete_fish_nearest_envrc)"
        if test -n "$nearest_envrc"
            if not set --query DIRENV_DIR
                # We get here in case #1
                _complete_fish_pre_load
            else
                if not set --query --global _complete_fish_direnv_loaded
                    # We get here in cases #4 and #5. #4 and #5 get here because exec
                    # or sub_shell would erase global variables, but not environment
                    # variables.
                    _complete_fish_pre_load
                else if test $is_moving_from_one_direnv_directly_to_another = true
                    # We get here in case #3
                    _complete_fish_pre_load
                    _complete_fish_pre_unload
                end
            end
        else
            if set --query DIRENV_DIR
                # We get here in case #2
                _complete_fish_pre_unload
            end
        end

        __direnv_export_eval_backup

        # Determine which post hooks should run
        if not set --query --global _complete_fish_direnv_loaded
            and set --query DIRENV_DIR

            # We get here in cases #1, #4, and #5. #4 and #5 get here because exec or
            # sub_shell would erase global variables, but not environment variables.
            set --global _complete_fish_direnv_loaded true
            _complete_fish_post_load
        else if set --query --global _complete_fish_direnv_loaded
            and not set --query DIRENV_DIR

            # We get here in case #2
            set --erase _complete_fish_direnv_loaded
            _complete_fish_post_unload
        else if test $is_moving_from_one_direnv_directly_to_another = true
            # We get here in case #3
            _complete_fish_post_unload
            _complete_fish_post_load
        end
    end

    __direnv_export_eval
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

function _complete_fish_is_moving_from_one_direnv_directly_to_another
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
