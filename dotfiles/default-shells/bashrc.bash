# I only want this file to be loaded when Bash is in interactive
# mode. There are two problems that I encountered when trying to do this. Below,
# I'll list the problems and my workarounds.
#   1. .bashrc does not get loaded when the shell is in interactive login
#     mode: To work around this, I added code to .bash_profile to source this file if
#     the shell is in interactive mode. This covers the interactive login mode case
#     since .bash_profile is always loaded when shell is started in login mode.
#   2. There are cases where .bashrc gets sourced even if the shell isn't in
#     interactive mode: To work around this, the conditional below will
#     exit this script early if the shell wasn't launched with the `-i` flag. The
#     cases are:
#       - Bash will source .bashrc whenever Bash is run by a remote shell daemon like
#         ssh[1].
#       - The default .profile on Pop!_OS sources .bashrc even if the shell isn't
#         interactive. I'm assuming this is done because Bash won't source .bashrc if
#         the shell is both interactive and login[2]. Even if that's the case, I
#         think a check for interactive mode should be added.
#
# The rules for how Bash decides what file to load can be found here:
# https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
#
# [1]: https://unix.stackexchange.com/questions/257571/why-does-bashrc-check-whether-the-current-shell-is-interactive
# [2]: https://stackoverflow.com/a/415444
if [[ $- != *i* ]]; then
  return
fi

# There are a few cases where Bash get launched interactively even though it won't be
# used interactively. This is a problem because I call `exec` in this script which
# usually breaks the program launching Bash. To work around this, I exit this script
# early if I detect any of these cases. The cases are:
#
# - VS Code's "shell resolution"[1], starts the default shell in interactive-login
# mode. Though they shouldn't be launching it in interactive mode if it isn't
# actually being used interactively. Apparently they do this because they think most
# users would want the configuration in their .bashrc to be applied to VS Code[2].
# `exec`ing into fish breaks their shell resolution so I first check to see if the
# shell was started for shell resolution using the environment variable that VS Code
# sets to indicate this[3].
#
# - Zed will launch the shell in interactive mode to resolve the environment. Unlike
#   VS Code, it doesn't set an environment variable to indicate that it's resolving
#   the environment. Instead, I check if stdin isn't a terminal.
#
# [1]: https://code.visualstudio.com/docs/supporting/FAQ#_resolving-shell-environment-fails
# [2]: https://github.com/microsoft/vscode/issues/177126#issuecomment-1630889619
# [3]: https://github.com/microsoft/vscode/issues/163186
if [[ -n ${VSCODE_RESOLVING_ENVIRONMENT:-} ]] || [[ ! -t 1 ]]; then
  return
fi

# If the current shell isn't fish, exec into fish. My reason for doing this is in
# README.md
fish_path="$(type -P fish)"
if [[ ${SHELL##*/} != 'fish' ]] && [[ -n $fish_path ]]; then
  SHELL="$fish_path" exec fish
fi
