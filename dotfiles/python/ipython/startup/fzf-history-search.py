# Based on this: https://github.com/infokiller/config-public/blob/30984c5234c382b1b5eb097872a535458cd6ec70/.config/ipython/profile_default/startup/ext/fzf_history.py

import datetime
import errno
import os
import sqlite3
import subprocess
import sys
from typing import Generator

import IPython

sqlite3.register_converter(
    "timestamp", lambda timestamp: datetime.datetime.fromisoformat(timestamp.decode())
)

# This startup file is also used by `jupyter console`, which doesn't use prompt
# toolkit, and may fail importing it.
try:
    import prompt_toolkit
    from prompt_toolkit.keys import Keys
except (ImportError, ValueError):
    pass


def _send_entry_to_fzf(entry: str, fzf):
    fzf_entry = "{}\0".format(entry.strip()).encode("utf-8")
    try:
        fzf.stdin.write(fzf_entry)
    except IOError as e:
        if e.errno == errno.EPIPE:
            return


def _create_fzf_process(initial_query):
    xdg_data_directory = os.environ.get(
        "XDG_DATA_HOME", f"{os.environ['HOME']}/.local/share"
    )
    fzf_history_directory = f"{xdg_data_directory}/fzf"
    fzf_history_file = f"{fzf_history_directory}/fzf-ipython-history.txt"
    subprocess.run(["mkdir", "-p", fzf_history_directory])
    subprocess.run(["touch", fzf_history_file])

    return subprocess.Popen(
        [
            "fzf",
            "--read0",
            "--no-sort",
            "--tiebreak=index",
            f"--history={fzf_history_file}",
            "--exact",
            "--query={}".format(initial_query),
            "--preview-window=follow",
            "--preview=echo {} | bat --language python",
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )


def _get_history_from_connection(con) -> Generator[str, None, None]:
    session_to_start_time = {}
    for session, start_time in con.execute("SELECT session, start FROM sessions"):
        session_to_start_time[session] = start_time
    query = """
    SELECT session, source_raw FROM (
        SELECT session, source_raw, rowid FROM history GROUP BY source_raw ORDER BY rowid DESC
    )
    """
    for session, source_raw in con.execute(query):
        yield (source_raw)


def _get_command_history(files=None) -> Generator[str, None, None]:
    hist_manager = IPython.get_ipython().history_manager
    if not files:
        files = [hist_manager.hist_file]
    for file in files:
        # detect_types causes timestamps to be returned as datetime objects.
        con = sqlite3.connect(
            file,
            detect_types=sqlite3.PARSE_DECLTYPES | sqlite3.PARSE_COLNAMES,
            **hist_manager.connection_options,
        )
        for entry in _get_history_from_connection(con):
            yield entry
        con.close()


def select_history_line(event, history_files=None):
    fzf = _create_fzf_process(event.current_buffer.text)
    for entry in _get_command_history(history_files):
        _send_entry_to_fzf(entry, fzf)
    stdout, stderr = fzf.communicate()
    if fzf.returncode == 0:
        event.current_buffer.document = prompt_toolkit.document.Document(
            stdout.decode("utf-8").strip()
        )
    # 130 is SIGINT so user probably just pressed ctrl+c
    elif fzf.returncode != 130:
        sys.stderr.write(str(stderr))


def _is_using_prompt_toolkit():
    return hasattr(IPython.get_ipython(), "pt_app")


if _is_using_prompt_toolkit():
    key_bindings = IPython.get_ipython().pt_app.key_bindings
    key_bindings.add(Keys.ControlR, filter=True)(select_history_line)
