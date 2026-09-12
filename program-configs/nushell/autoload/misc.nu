use std/bench
use std/clip
use std/util "path add"

$env.config.show_banner = false
$env.config.completions.algorithm = "fuzzy"
$env.config.max_last_result_size = 1mb
$env.config.filesize = { unit: "binary" }
$env.config.use_kitty_protocol = true
$env.config.buffer_editor = 'nvim'
$env.config.keybindings ++= [
  {
    name: smart_explore
    modifier: control
    keycode: char_x
    mode: [emacs vi_insert vi_normal]
    event: [
      {
        cmd: "
          if (commandline | is-empty) {
            if __ans not-in $env or $ans.last != null {
              $env.__ans = $ans.last
            }
            commandline edit '$env.__ans'
          }
          commandline edit --accept --append ' | explore'
        "
        send: ExecuteHostCommand
      }
    ]
  }
  {
    name: paste
    modifier: control
    keycode: char_v
    mode: [emacs vi_insert vi_normal]
    event: {
      cmd: "commandline edit --insert (pbpaste)"
      send: ExecuteHostCommand
    }
  }
]

$env.config.ls.use_ls_colors = false

# Set preferred editor. Programs check either of these variables for the
# preferred editor so I'll set both. For more information on the meaning of
# these variables, see:
# https://unix.stackexchange.com/a/302391
$env.EDITOR = (which nvim).0.path
$env.VISUAL = $env.EDITOR
alias vim = nvim

alias g = git
alias trash = rm --trash
alias r = exec nu
alias pbpaste = clip paste52
alias pbcopy = clip copy52
alias x = chmod +x

path add ~/.local/bin

def --wrapped s [...args] {
  sudo s sudo ...$args
}

def ls [...pattern: oneof<glob, string>] {
  if ($pattern | is-not-empty) {
    %ls --all --long ...$pattern
  } else {
    %ls --all --long
  }
    | reject num_links inode accessed created
}
