# Based on this: https://github.com/infokiller/config-public/blob/30984c5234c382b1b5eb097872a535458cd6ec70/.config/ipython/profile_default/startup/ext/fzf_history.py

import os
import sqlite3
import subprocess
import sys
from sqlite3 import Connection
from subprocess import CalledProcessError, check_output
from typing import Any, Iterable

from IPython.core.getipython import get_ipython


def get_history_entries_for_connection(connection: Connection) -> Iterable[str]:
    query = "SELECT source_raw FROM history GROUP BY source_raw ORDER BY rowid DESC"
    return (row[0] for row in connection.execute(query))


def get_history_entries(files: list[str] | None = None) -> Iterable[str]:
    ipython = get_ipython()
    assert ipython is not None

    history_manager = ipython.history_manager
    assert history_manager is not None

    if not files:
        files = [history_manager.hist_file]

    for file in files:
        with sqlite3.connect(
            file,
            **history_manager.connection_options,
        ) as connection:
            yield from get_history_entries_for_connection(connection)


def history_widget(event: Any, history_files: list[str] | None = None) -> None:
    xdg_data_directory = os.environ.get(
        "XDG_DATA_HOME", f"{os.environ['HOME']}/.local/share"
    )
    fzf_history_directory = f"{xdg_data_directory}/fzf"
    fzf_history_file = f"{fzf_history_directory}/fzf-ipython-history.txt"
    subprocess.run(["mkdir", "-p", fzf_history_directory])
    subprocess.run(["touch", fzf_history_file])

    try:
        choice = check_output(
            [
                "fzf",
                "--read0",
                "--no-sort",
                "--tiebreak=index",
                f"--history={fzf_history_file}",
                "--exact",
                f"--query={event.current_buffer.text}",
                "--preview-window=follow",
                "--preview=echo {} | bat --language python",
            ],
            input="\0".join(get_history_entries(history_files)).encode("utf-8"),
        )

        import prompt_toolkit

        event.current_buffer.document = prompt_toolkit.document.Document(
            choice.decode("utf-8").strip()
        )
    except CalledProcessError as error:
        # 130 is returned when the user exits without picking something
        if error.returncode != 130:
            sys.stderr.write(error.output)


def is_using_prompt_toolkit() -> bool:
    ipython = get_ipython()
    assert ipython is not None

    return hasattr(ipython, "pt_app")


def main() -> None:
    # This startup file is also used by `jupyter console`, which doesn't use
    # prompt toolkit
    if not is_using_prompt_toolkit():
        return

    from prompt_toolkit.keys import Keys

    ipython = get_ipython()
    assert ipython is not None

    ipython.pt_app.key_bindings.add(Keys.ControlR, filter=True)(history_widget)


main()
