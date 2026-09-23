use std/bench
use std/clip
use std/util "path add"

path add ~/.local/bin

$env.config.abbreviations.chase = 'chase --verbose'
$env.config.abbreviations.g = 'git'
$env.config.abbreviations.trash = 'rm --recursive --trash'
$env.config.abbreviations.x = 'chmod +x'
$env.config.completions.algorithm = "fuzzy"
$env.config.filesize = { unit: "binary" }
$env.config.max_last_result_size = 1mb
$env.config.show_banner = false
$env.config.use_kitty_protocol = true
$env.config.table.missing_value_symbol = "—"

alias timg = timg --center
alias r = exec nu
alias pbpaste = clip paste52
alias pbcopy = clip copy52

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
  {
    name: open_editor
    modifier: alt
    keycode: char_e
    mode: [emacs, vi_normal, vi_insert]
    event: { send: OpenEditor }
  }
  {
    name: previous_history
    modifier: control
    keycode: 'char_['
    mode: [emacs, vi_normal, vi_insert]
    event: { send: PreviousHistory }
  }
  {
    name: next_history
    modifier: control
    keycode: 'char_]'
    mode: [emacs, vi_normal, vi_insert]
    event: { send: NextHistory }
  }
  {
    name: help_menu_2
    modifier: control_shift
    keycode: char_h
    mode: [emacs, vi_insert, vi_normal]
    event: { send: menu, name: help_menu }
  }
]

$env.config.completions.external.completer = {|spans|
  fish --command 'complete --do-complete "$(string join -- " " $argv)"' ...$spans
    | from tsv --flexible --noheaders --no-infer
    | rename value description
    | update value {|row|
        let value = $row.value
        let need_quote = ['\' ',' '[' ']' '(' ')' ' ' '\t' "'" '"' "`"] | any {$in in $value}
        if ($need_quote and ($value | path exists)) {
          let expanded_path = if ($value starts-with ~) {$value | path expand --no-symlink} else {$value}
          $'"($expanded_path | str replace --all "\"" "\\\"")"'
        } else {
          $value
        }
      }
}

# Set preferred editor. Programs check either of these variables for the
# preferred editor so I'll set both. For more information on the meaning of
# these variables, see:
# https://unix.stackexchange.com/a/302391
$env.EDITOR = (which nvim).0.path
$env.VISUAL = $env.EDITOR
$env.config.abbreviations.vim = 'nvim'

# Choose job to unfreeze interactively if multiple exist
def "job my-unfreeze" [] {
  job list
    | where type == frozen
    | match ($in | length) {
        0 => null
        1 => { first }
        _ => { input list --display {|job| $job.description? | default $job.id} }
      }
    | if $in != null {
        job unfreeze $in.id
      }
}
$env.config.keybindings ++= [
  {
    name: job_interactive_unfreeze
    modifier: control
    keycode: char_z
    mode: [emacs vi_insert vi_normal]
    event: { cmd: "job my-unfreeze", send: ExecuteHostCommand }
  }
]

# sudo
def "nu-complete s" [spans] {
  do $env.config.completions.external.completer ($spans | skip 1)
}
@complete 'nu-complete s'
def --wrapped s [...args] {
  sudo s sudo ...$args
}
def elevate [] {
  sudo s sudo $env.SHELL
}

def ls [...pattern: oneof<glob, string>] {
  if ($pattern | is-not-empty) {
    %ls --all --long ...$pattern
  } else {
    %ls --all --long
  }
    | reject num_links inode accessed created
}

# fzf
$env.FZF_DEFAULT_OPTS_FILE = $env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config" | $"($in)/fzf/default-opts.txt"
$env.FZF_DEFAULT_OPTS = $env.XDG_DATA_HOME? | default $"($env.HOME)/.local/share" | $"--history=($in)/fzf/history.txt"

# man
$env.MANOPT = --no-hyphenation

# less
$env.config.abbreviations.page = 'less'
$env.PAGER = 'less'
# This isn't in the portable home
if (which lesspipe.sh | is-not-empty) {
  $env.LESSOPEN = '|lesspipe.sh %s'
}
# TODO: lesspipe requires this to be set to enable syntax highlighting. I should open
# an issue to have it read lesskey
$env.LESS = '-R'
# Have lesspipe use bat for syntax highlighting
$env.LESSCOLORIZER = 'bat'

# python
#
# Don't add the name of the virtual environment to my prompt. This way, I can add it
# myself using the same formatting as the rest of my prompt.
$env.VIRTUAL_ENV_DISABLE_PROMPT = 1

# zoxide
$env._ZO_FZF_OPTS = $"($env.FZF_DEFAULT_OPTS) --preview 'ls {2}' --keep-right --tiebreak index"
alias cd = __zoxide_z
alias cdh = __zoxide_zi

# ulimit
#
# Increase maxixmum number of open file descriptors that a single process can
# have. This applies to the current process and its descendents.
ulimit -Sn 10000

# vscode
@complete external
def --wrapped code [ ...rest: string ] {
  # Clear SHELL because my config for the login shell only launches my shell if the current SHELL isn't mine.
  with-env {SHELL: ''} { ^code ...$rest }
}

# comma
def "nu-complete my-comma" [spans] {
  # Use comma instead of `,` since autocomplete is only defined for comma
  do $env.config.completions.external.completer ($spans | each { str replace --regex '^,$' 'comma' })
}
@complete 'nu-complete my-comma'
def --wrapped , [ ...rest: string ] {
  with-env {
    # `--with-nth` removes the '.out' extension from the entries.
    FZF_DEFAULT_OPTS: $"($env.FZF_DEFAULT_OPTS) --separator '' --height 10 --margin 0,2,0,2 --preview-window right,75%,border-left --preview 'nix-search --details --max-results 1 --name \(string sub --end -4 {})' --delimiter '.out' --with-nth '{1}'"
    COMMA_PICKER: 'fzf'
  } {
    ^, --cache-level 0 ...$rest
  }
}

# touch
def touchx [name: path] {
  touchp $name
  chmod +x $name
}
def touchp [name: path] {
  $name | path dirname | mkdir $in
  touch $name
}

def tunnel [port: int] {
  (
    doppler run
      --mount ~/.cloudflared/2c881c12-5fd8-4f5e-a2f4-f692af8abffa.json
      --mount-template (let temp = (mktemp); '{{.CLOUDFLARED_TUNNEL}}' | save --force $temp; $temp)
      --mount-max-reads 1
      --
      cloudflared tunnel run --url $"http://localhost:($port)"
  )
}

@complete external
def --wrapped watch [ ...rest: string ] {
  viddy --disable_auto_save ...$rest
}
$env.config.abbreviations.watch = 'watch --differences --interval 1s --exec'

def dui [] {
  br --whale-spotting
}
$env.config.abbreviations.t = r#'broot --cmd ':toggle_preview;:toggle_watch''#
$env.config.abbreviations.tl = r#'broot --sizes --dates --permissions'#

$env.RIPGREP_CONFIG_PATH = $env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config" | $"($in)/ripgrep/ripgreprc"

# diffoscope
def "nu-complete diff-html" [spans] {
  do $env.config.completions.external.completer ($spans | each { str replace --regex '^diff-html$' 'diffoscope' })
}
@complete 'nu-complete diff-html'
def --wrapped diff-html [...args] {
  let temp = mktemp --suffix .html
  (
    diffoscope
      --html $temp
      --jquery 'https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js'
      ...$args
  )
  ^open $temp
}
def "nu-complete my-diff" [spans] {
  do $env.config.completions.external.completer ($spans | each { str replace --regex '^diff$' 'diffoscope' })
}
@complete 'nu-complete my-diff'
def --wrapped diff [...args] {
  diffoscope --text-color always ...$args
    | if (is-terminal --stdout) and not (is-redirected) {
        ^$env.PAGER
      } else {
        $in
      }
}

# nix
#
# Lets me start a nix shell with python and the specified python packages.
# Example: `nix-py requests marshmallow`
def "nu-complete nix-py" [spans] {
  let last_token = $spans | last
  nix eval --raw --impure --expr 'with builtins; concatStringsSep "\n" (attrNames (import <nixpkgs> {}).python3Packages)'
    | lines
    | where $it starts-with $last_token
}
@complete 'nu-complete nix-py'
def nix-py [...packages: string] {
    let package_string = $packages | str join " "
    nix shell --impure --expr $"\(import <nixpkgs> {}).python3.withPackages \(p: with p; [($package_string)])"
}
def "nu-complete nix-is-cached" [spans] {
  [nix build]
    | if ($spans | is-not-empty) {
        $in | append ($spans | last)
      } else {
        $in
      }
    | do $env.config.completions.external.completer $in
}
@complete 'nu-complete nix-is-cached'
def --wrapped nix-is-cached [...packages: string] {
    nix build --impure --dry-run ...$packages
}
def nix-store-size [] {
  nix-sweep analyze --all
}
def nix-store-clean [] {
  nix-sweep tidyup-gc-roots --older '2 weeks' --force

  [
    ...(glob /nix/var/nix/profiles/{default,per-user/root/profile})
    ...(glob ~/.local/state/nix/profiles/{profile,home-manager})
  ]
    | if $nu.os-info.name == linux {
        append /nix/var/nix/profiles/system-manager-profiles/system-manager
      } else {
        $in
      }
    | if $nu.os-info.name == macos {
        append /nix/var/nix/profiles/system
      } else {
        $in
      }
    | each { sudo s sudo -H nix profile wipe-history --profile $in }

  nix-collect-garbage
}

def "nu-complete task" [spans] {
  $spans
    | each {|span|
        if $span == task {
          if (which just | is-not-empty) {
            'just'
          } else if (which mise | is-not-empty) {
            # mise goes last since I install it globally
            [ mise run ]
          }
        } else {
          $span
        }
      }
    | flatten
    | do $env.config.completions.external.completer $in
}
@complete 'nu-complete task'
def --wrapped task [...args] {
  let exec_args = if (which just | is-not-empty) {
    [ just ]
  } else if (which mise | is-not-empty) {
    # mise goes last since I install it globally
    [ mise run ]
  }
    | append $args

  run-external ...$exec_args
}
