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
# - Zed will launch the shell in interactive mode to resolve the environment. Unlike
#   VS Code, it doesn't set an environment variable to indicate that it's resolving
#   the environment. Instead, I check if stdin isn't a terminal.
#
# [1]: https://code.visualstudio.com/docs/supporting/FAQ#_resolving-shell-environment-fails
# [2]: https://github.com/microsoft/vscode/issues/177126#issuecomment-1630889619
# [3]: https://github.com/microsoft/vscode/issues/163186
if ((${+VSCODE_RESOLVING_ENVIRONMENT})) || [ ! -t 1 ]; then
	return
fi

# If the current shell isn't fish, exec into fish.
if [ "$SHELL:t" != 'fish' ] && (($+commands[fish])); then
	SHELL="$(command -v fish)" exec fish
fi
