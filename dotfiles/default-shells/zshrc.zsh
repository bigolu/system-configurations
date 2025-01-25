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
# When trying to load the environment for one of my hammerspoon spoons, I launch
# the shell in interactive mode, even though it isn't actually being used
# interactively. Like VS Code, I set an environment variable so I can detect
# when I'm doing this. My reason for using interactive mode can be found in
# Speakers.spoon/init.lua.
#
# [1]: https://code.visualstudio.com/docs/supporting/FAQ#_resolving-shell-environment-fails
# [2]: https://github.com/microsoft/vscode/issues/177126#issuecomment-1630889619
# [3]: https://github.com/microsoft/vscode/issues/163186
if ! (( ${+VSCODE_RESOLVING_ENVIRONMENT} )) && ! (( ${+HAMMERSPOON_RESOLVING_ENVIRONMENT} )); then
  # If the current shell isn't fish, exec into fish. My reason for doing this is in README.md
  if [ "$(basename "$SHELL")" != 'fish' ]; then
    SHELL="$(command -v fish)" exec fish
  fi
fi
