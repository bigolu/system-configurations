$env.PROMPT_COMMAND_RIGHT = ''
$env.TRANSIENT_PROMPT_INDICATOR = ''

$env.TRANSIENT_PROMPT_COMMAND = {
  [
    (format-path $env.PWD)
    (date now | format date '%r')
  ]
    | str join '  '
    | $"\n(ansi light_gray_reverse) ($in) (ansi reset) "
}

$env.PROMPT_COMMAND = {
  let last_exit_code = $env.LAST_EXIT_CODE

  # The max number of screen columns a context can use and still fit on one
  # line. The 4 accounts for the 4 characters that make up the border.
  # `max` ensures the value is never negative
  let max_context_length = [ ((term size).columns - 4) 1 ] | math max

  let colors = {
    reset: (ansi reset)
    success: (ansi green)
    warning: (ansi yellow)
    error: (ansi red)
    border: (ansi light_gray)
  }

  let job_ignore_label = 'ignore'
  let async_prompt_var = 'NU_ASYNC_PROMPT'

  def main [] {
    let prompt = [
      (job-context)
      (broot-context)
      (direnv-context)
      (nix-context)
      (python-context)
      (git-context)
      (path-context)
      (login-context)
      (level-context)
      (status-context)
    ]
      | compact
      | make_lines
      | prepend ''
      | append (make_line last)
      | str join "\n"

    if $async_prompt_var not-in $env {
      job spawn --description $job_ignore_label {
        with-env { $async_prompt_var: true } { do $env.PROMPT_COMMAND }
          | commandline set-prompt
      }
    }

    $prompt
  }

  def make_lines []: list<string> -> list<string> {
    $in
      | enumerate
      | each {|elt|
          make_line (if $elt.index == 0 { 'first' } else { 'middle' }) $elt.item
        }
  }
  
  def make_line [position: string, context?: string] {
    match $position {
      'first' => $'($colors.border)┌($colors.reset)(add_context_border $context)'
      'middle' => $'($colors.border)├($colors.reset)(add_context_border $context)'
      'last' => $'($colors.border)└($colors.reset)'
    }
  }
  
  def add_context_border [context: string] {
    $'($colors.border)╼[($colors.reset)($context)($colors.border)]($colors.reset)'
  }

  def python-context [] {
    if VIRTUAL_ENV not-in $env {
      return
    }

    $'venv: (format-path $env.VIRTUAL_ENV)'
  }

  def level-context [] {
    if ($env.SHLVL? | default 1) == 1 {
      return
    }

    $'level: ($env.SHLVL)'
  }

  def direnv-context [] {
    if DIRENV_DIR not-in $env {
      return
    }

    $env.DIRENV_DIR
      # DIRENV_DIR starts with '-' so we remove it
      | str substring 1..
      | format-path
      # TODO: A better way to check this is in the works: https://github.com/direnv/direnv/pull/1010
      #
      # The number I'm matching is the value of an enum that's defined here:
      # https://github.com/direnv/direnv/blob/f5deb57e5944978c6a0017bbcb2a808e3e59fb21/internal/cmd/rc.go#L145-L149
      | if (direnv status) like 'Loaded RC allowed [1,2]' {
          $"($in) \(($colors.warning)blocked($colors.reset))"
        } else {
          $in
        }
      | $'direnv: ($in)'
  }

  def nix-context [] {
    if IN_NIX_SHELL not-in $env and IN_NIX_RUN not-in $env {
      return
    }

    $env.name?
      | default $'(ansi attr_italic)no name($colors.reset)'
      | $'nix: ($in)'
  }

  def broot-context [] {
    if IN_BROOT not-in $env {
      return
    }

    $'broot: ($colors.warning)active($colors.reset)'
  }

  def path-context [] {
    $'path: (format-path $env.PWD)'
  }

  def job-context [] {
    let jobs = job list | where $it.description? != $job_ignore_label
    if ($jobs | is-empty) {
      return
    }

    $jobs
      | each {|job| $job.description? | default $job.id}
      | str join ', '
      | $'jobs: ($in)'
  }

  def login-context [] {
    let container_name = get-container-name
    let host_attributes = []
      | if $container_name != null {
          $in | append $'($colors.warning)container:($container_name)($colors.reset)'
        } else {
          $in
        }
      | if SSH_TTY in $env {
          $in | append $'($colors.warning)ssh($colors.reset)'
        } else {
          $in
        }

    let privilege = if (is-admin) { $'($colors.warning)superuser($colors.reset)' }

    if ($host_attributes | is-empty) and $privilege == null {
      return
    }

    let user = whoami
      | if $privilege != null {
          $"($in) \(($privilege))"
        } else {
          $in
        }

    let host = sys host
      | get hostname
      | if ($host_attributes | is-not-empty) {
          $"($in) \(($host_attributes | str join ', '))"
        } else {
          $in
        }

    $'login: ($user) on ($host)'
  }
  
  # Adapted from Starship Prompt: https://github.com/starship/starship/blob/master/src/modules/container.rs
  def get-container-name []: nothing -> oneof<string, nothing> {
    let systemd_container_path = '/run/systemd/container'

    if ('/proc/vz' | path exists) and (not ('/proc/bc' | path exists)) {
      'OpenVZ'
    } else if ('/run/host/container-manager' | path exists) {
      'OCI'
    } else if ('/run/.containerenv' | path exists) {
      # TODO: The image name is in the file, I should extract it and return that instead.
      'podman'
    } else if ($systemd_container_path | path exists) {
      open --raw $systemd_container_path
    } else if ('/.dockerenv' | path exists) {
      'Docker'
    }
  }

  def status-context [] {
    if $last_exit_code == 0 {
      return
    }

    $last_exit_code
      | format-exit-code
      | $'status: ($in)'
  }

  def format-exit-code []: int -> string {
    let code = $in
    let signal = get-exit-code-signal $code

    $code
      | if $signal != null {
          $'($in)/($signal)'
        } else {
          $in
        }
      | $'(get-exit-code-color $code)($in)($colors.reset)'
  }
  
  def get-exit-code-color [code: int] {
    match $code {
      -2 | 130 => $colors.warning
      _ => $colors.error
    }
  }

  def get-exit-code-signal [code: int] {
    match $code {
      -1 => 'SIGHUP'
      -2 => 'SIGINT'
      -3 => 'SIGQUIT'
      -4 => 'SIGILL'
      -6 => 'SIGABRT'
      -9 => 'SIGKILL'
      -11 => 'SIGSEGV'
      -15 => 'SIGTERM'

      129 => 'SIGHUP'
      130 => 'SIGINT'
      131 => 'SIGQUIT'
      132 => 'SIGILL'
      133 => 'SIGTRAP'
      134 => 'SIGABRT'
      135 => 'SIGBUS'
      136 => 'SIGFPE'
      139 => 'SIGSEGV'
      140 => 'SIGUSR2'
      141 => 'SIGPIPE'
      142 => 'SIGALRM'
      143 => 'SIGTERM'
      144 => 'SIGSTKFLT'
      152 => 'SIGXCPU'
      153 => 'SIGXFSZ'
      154 => 'SIGVTALRM'
      155 => 'SIGPROF'
      157 => 'SIGIO'
      158 => 'SIGPWR'
      159 => 'SIGSYS'
      _ => null
    }
  }

  def git-context [] {
    # This way we don't print the git section and possibly remove it later
    # because the directory wasn't in a git repo.
    if (git rev-parse --is-inside-work-tree | complete).exit_code != 0 {
      return
    }

    if $async_prompt_var in $env {
      # TODO: Implement in nushell to avoid overhead of going through fish
      fish -c r#'
        set --global __fish_git_prompt_showupstream informative
        set --global __fish_git_prompt_showdirtystate 1
        set --global __fish_git_prompt_showuntrackedfiles 1
        set --global __fish_git_prompt_char_upstream_ahead ',ahead:'
        set --global __fish_git_prompt_char_upstream_behind ',behind:'
        set --global __fish_git_prompt_char_untrackedfiles ',untracked'
        set --global __fish_git_prompt_char_dirtystate ',dirty'
        set --global __fish_git_prompt_char_stagedstate ',staged'
        set --global __fish_git_prompt_char_invalidstate ',invalid'
        set --global __fish_git_prompt_char_stateseparator ''
        set git_status (fish_git_prompt)

        # remove parentheses and leading space
        # e.g. ' (<branch>,dirty,untracked)' -> '<branch>,dirty,untracked'
        set --local formatted_status (string sub --start=3 --end=-1 $git_status)

        # replace first comma with ', '
        # '<branch>,dirty,untracked' -> '<branch> (dirty,untracked'
        set --local formatted_status (string replace ',' ' (' $formatted_status)
        # only add the closing parentheses if we added the opening one
        and set formatted_status (string join '' $formatted_status ')')

        echo "$formatted_status"
      '#
    } else {
      $'(ansi light_gray_italic)loading($colors.reset)'
    }
      | $'git: ($in)'
  }

  main
}

def format-path [path?: string]: oneof<string,nothing> -> string {
  let path_in = $in
  let path = $path | default $path_in
  $path
    | str replace --regex $"^($nu.home-dir)" "~"
    # If we're on a local machine, add a hyperlink
    | if SSH_TTY not-in $env {
        let original_in = $in;
        $'file://($path)' | ansi link --text $original_in
      } else {
        $in
      }
}
