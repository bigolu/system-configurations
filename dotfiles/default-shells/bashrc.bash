# I only want this file (.bashrc) to be loaded when Bash is in interactive
# mode. There are two problems that I encountered when trying to do this. Below,
# I'll list the problems and my workarounds.
#   - .bashrc does not get loaded when the shell is in interactive _login_
#     mode: To workaround this, I added code to .bash_profile to source this file if
#     the shell is in interactive mode. This covers the interactive login mode case
#     since .bash_profile is always loaded when shell is started in login mode.
#   - There are cases where .bashrc gets sourced even if the shell isn't in
#     interactive mode: To workaround this, I have conditionals below that will
#     return early if this shell isn't actually in interactive mode.
#
# The rules for how Bash decides what file to load can be found here:
# https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html

# Sometimes, .bashrc is sourced even if the shell isn't in interactive mode:
#   - bash will source .bashrc whenever bash is run by a remote shell daemon like
#     ssh[1].
#   - The default .profile on Pop!_OS sources .bashrc even if the shell isn't
#     interactive. I'm assuming this is done because bash won't source .bashrc if
#     the shell is both interactive and login[2]. Even if that's the case, I
#     think a check for interactive mode should be added.
#
# [1]: https://unix.stackexchange.com/questions/257571/why-does-bashrc-check-whether-the-current-shell-is-interactive
# [2]: https://stackoverflow.com/a/415444
if [[ $- != *i* ]]; then
  return
fi

# As part of VS Code's "shell resolution"[1], it starts the default shell in
# interactive-login mode. Though they shouldn't be launching it in interactive
# mode if it isn't actually being used interactively. Apparently they do this
# because they think most users would want the configuration in their .bashrc to
# be applied to VS Code[2].
#
# `exec`ing into fish breaks their shell resolution so I first check to see if
# the shell was started for shell resolution using the environment variable that
# VS Code sets to indicate this[3].
#
# [1]: https://code.visualstudio.com/docs/supporting/FAQ#_resolving-shell-environment-fails
# [2]: https://github.com/microsoft/vscode/issues/177126#issuecomment-1630889619
# [3]: https://github.com/microsoft/vscode/issues/163186
if [[ -n ${VSCODE_RESOLVING_ENVIRONMENT+set} ]]; then
  return
fi

# If the current shell isn't fish, exec into fish. My reason for doing this is in README.md
if [[ "$(basename "$SHELL")" != 'fish' ]]; then
  SHELL="$(command -v fish)" exec fish
fi
