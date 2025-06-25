# There are a few cases where Zsh get launched interactively even though it won't be
# used interactively. This is a problem because I call `exec` in this script which
# usually breaks the program launching Zsh. To work around this, I exit this script
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
# - When trying to load the environment for one of my hammerspoon spoons, I launch
# the shell in interactive mode, even though it isn't actually being used
# interactively. Like VS Code, I set an environment variable so I can detect when I'm
# doing this. My reason for using interactive mode can be found in
# Speakers.spoon/init.lua.
#
# - Zed will launch the shell in interactive mode to resolve the environment. Unlike
#   VS Code, it doesn't set an environment variable to indicate that it's resolving
#   the environment. Instead, I check if stdin isn't a terminal.
#
# [1]: https://code.visualstudio.com/docs/supporting/FAQ#_resolving-shell-environment-fails
# [2]: https://github.com/microsoft/vscode/issues/177126#issuecomment-1630889619
# [3]: https://github.com/microsoft/vscode/issues/163186
if
  (( ${+VSCODE_RESOLVING_ENVIRONMENT} )) \
    || (( ${+HAMMERSPOON_RESOLVING_ENVIRONMENT} )) \
    || [ ! -t 1 ]
then
  return
fi

# If the shell is a login shell, source the login config now because normally, it
# would run after this file, but that won't happen since I use exec below.
if [[ -o login ]] &&  [ -f ~/.zlogin ]; then
  source ~/.zlogin
fi

# If the current shell isn't fish, exec into fish. My reason for doing this is in
# README.md
if [ "$SHELL:t" != 'fish' ] && (( $+commands[fish] )); then
  SHELL="$(command -v fish)" exec fish
fi
