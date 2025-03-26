c = get_config()  # noqa: F821

c.InteractiveShellApp.extensions = ["autoreload", "storemagic"]
c.TerminalIPythonApp.display_banner = False
c.TerminalInteractiveShell.confirm_exit = False
c.TerminalInteractiveShell.shortcuts = [
    {"command": "IPython:shortcuts.open_input_in_editor", "new_keys": ["c-e"]}
]
c.TerminalInteractiveShell.highlighting_style = "bw"
