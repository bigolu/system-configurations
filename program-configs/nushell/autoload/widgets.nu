module widgets {
  const dir_placeholder = '{bigolu_dir}'

  export-env {
    $env.config.keybindings ++= [
      {
        name: widget_history
        modifier: control
        keycode: char_h
        mode: [emacs vi_insert vi_normal]
        event: { cmd: "widget history", send: ExecuteHostCommand }
      }
      {
        name: widget_directories
        modifier: alt
        keycode: char_d
        mode: [emacs vi_insert vi_normal]
        event: { cmd: "widget directories", send: ExecuteHostCommand }
      }
      {
        name: widget_files
        modifier: control
        keycode: char_f
        mode: [emacs vi_insert vi_normal]
        event: { cmd: "widget files", send: ExecuteHostCommand }
      }
      {
        name: widget_grep_all
        modifier: alt
        keycode: char_g
        mode: [emacs vi_insert vi_normal]
        event: { cmd: "widget grep-all", send: ExecuteHostCommand }
      }
      {
        name: widget_grep
        modifier: control
        keycode: char_g
        mode: [emacs vi_insert vi_normal]
        event: { cmd: "widget grep", send: ExecuteHostCommand }
      }
      {
        name: widget_grep_ast
        modifier: alt
        keycode: char_a
        mode: [emacs vi_insert vi_normal]
        event: { cmd: "widget grep-ast", send: ExecuteHostCommand }
      }
    ]

    $env.config.abbreviations.vw = 'widget variables'
    $env.config.abbreviations.mw = 'widget manpages'
    $env.config.abbreviations.pw = 'widget processes'
  }

  # Fuzzy search various collections
  export def widget [] { }

  export def "widget history" [] {
    # Separate entries by nul since they may span multiple lines.
    with-env { FZF_DEFAULT_COMMAND: 'history | reverse | get command | uniq | str join (char nul)' } {
      (
        fzf
          --prompt 'history: '
          --no-preview
          --scheme history
          --no-hscroll
          --read0
          --print0
      )
    }
      | str trim --right --char (char nul)
      | split row (char nul)
      | str join "\n"
      | commandline edit --insert $in
  }

  export def "widget variables" [] {
    let non_env_vars = scope variables
      | upsert name { str substring 1.. }
      | each {|var| $"($var.name)\t($var.value)" }

    let env_vars = $env
      | columns
      | where $it != config
      | each {|name| $"($name)\t($env | get $name)" }

    ($non_env_vars ++ $env_vars)
      | str join (char nul)
      | (
          fzf
            --read0
            --print0
            --delimiter "\t"
            --with-nth 1
            --preview 'echo {2..}'
            --prompt '$'
        )
      | str trim --right --char (char nul)
      | split row (char nul)
      | each { split row "\t" | first }
      | str join ' '
      | commandline edit --insert $in
  }

  export def "widget directories" [] {
    with-env { FZF_DEFAULT_COMMAND: 'fd --strip-cwd-prefix --follow --hidden --type directory --type symlink' } {
      (
        fzf
          --prompt './'
          --preview 'print ($"(ansi light_gray)Directory: " + {}); ls --short-names {}'
          --preview-window '75%,~1'
          --keep-right
      )
    }
      | lines
      | each { to nuon }
      | str join " "
      | commandline edit --insert $in
  }

  export def "widget files" [] {
    with-env {
      FZF_HINTS: 'alt+e: edit in neovim'
      FZF_DEFAULT_COMMAND: 'fd --strip-cwd-prefix --follow --hidden --type file --type symlink'
    } {
      (
        fzf
          --prompt './'
          --preview r#'
            if (file --brief --mime-type {} | str contains --ignore-case image) {
                # TODO: timg can detect ghostty outside of fzf, but not in it
                #
                # TODO: timg cannot detect the line and column count of the screen in fzf
                timg -p kitty --center -g ($env.FZF_PREVIEW_COLUMNS + 'x' + $env.FZF_PREVIEW_LINES) {}
            } else {
                bat --style='header-filename' --color always --paging=never --terminal-width ($env.FZF_PREVIEW_COLUMNS | into int | $in - 2) {}
            }
          '#
          --preview-window '75%,~1'
          --bind "alt-e:execute:nvim {1} </dev/tty >/dev/tty 2>&1"
      )
    }
      | lines
      | each { to nuon }
      | str join " "
      | commandline edit --insert $in
  }

  export def "widget manpages" [] {
    with-env { FZF_DEFAULT_COMMAND: 'man -k .' } {
      (
        fzf
          --tiebreak 'chunk,begin,end'
          --prompt 'manpages: '
          --preview r#'
            echo {}
              # SYNC: parse
              | parse --regex '(?<name>^[^ ]*?)\s*\((?<section>.*?)\)\s+.*'
              | first
              | with-env {MANWIDTH: $env.FZF_PREVIEW_COLUMNS} {man $in.section $in.name}
          '#
          --preview-window '75%'
      )
    }
      | str trim --right --char "\n"
      # SYNC: parse
      | parse --regex '(?<name>^[^ ]*?)\s*\((?<section>.*?)\)\s+.*'
      | first
      | man $in.section $in.name
  }

  export def "widget grep-all" [] {
    let grep_command = 'rga --files-with-matches --rga-cache-max-blob-len=10M --'

    with-env { FZF_DEFAULT_COMMAND: 'ignore' } {
      (
        fzf
          --disabled
          # Use sleep to debounce
          --bind $"change:first+reload:sleep 100ms; try { ($grep_command) {q} }"
          --bind $'start:reload:($grep_command) ""'
          --prompt 'pattern: '
          --preview 'rga --pretty --context 5 {q} --rga-fzf-path=_{}'
      )
    }
      | lines
      | each { to nuon }
      | str join " "
      | commandline edit --insert $in
  }

  export def "widget processes" [] {
    let reload_command = 'ps --long | select user_id pid ppid priority start_time command | sort-by start_time | to tsv'
    let environment_flag = if $nu.os-info.name == linux { 'e' } else { '-E' }

    let preview_command = $"
      if \(ps | not \($in | any {|row| $row.pid == \(echo {2} | into int) })) {
        print 'There is no running process with this ID.'
        exit
      }

      # TODO: fzf doesn't escape values properly for nu so we wrap it in a raw string
      print \(\(ansi light_gray) + r#####'{}'##### + \(ansi reset))

      # I concatenate the fzf placeholders with the rest of the grep regex since
      # fzf substitutions are single quoted and the quotes would mess up the grep
      # regex.
      (
        if $nu.os-info.name == linux {
          '
            pstree --hide-threads --long --show-pids --unicode --show-parents --arguments {2} |
                rg --color always --passthru ("[^└|─]+," + {2} + "( .*|$)")
          '
        } else {
          '
            pstree -w -g 3 -p {2} |
                rg --color always --passthru (" 0*" + {2} + " " + {1} + " .*")
          '
        }
      )
    "

    let trace_command = if $nu.os-info.name == linux {
      r#'
        if (ps --long | any {|row| $row.pid == {2} and $row.user_id == 0 }) and not (is-admin) {
          # This avoids being prompted for my password while strace is running,
          # since it will be running at the same time as fzf in a pipeline.
          sudo -v

          sudo strace --summary --absolute-timestamps --attach={2}
        } else {
          strace --summary --absolute-timestamps --attach={2}
        }
      '#
    } else {
      r#'
        # This avoids being prompted for my password while strace is running,
        # since it will be running at the same time as fzf in a pipeline.
        sudo -v

        # TODO: Since dtruss doesn't exit upon receiving SIGPIPE, after I exit the
        # fzf viewer for the dtruss output, I have to hit ctrl-c again to get dtruss
        # to exit. I guess this is unavoidable since dtruss is a bash script and bash
        # is single threaded so it can't handle SIGPIPE until dtrace exits. I'd use
        # dtrace directly, which does respond to SIGPIPE, but getting it to print
        # system calls and all their arguments isn't trivial so I'd rather let dtruss
        # do that.
        sudo -- dtruss -a -p {2}
      '#
    }

    let environment_command = $"
      if \(ps --long | any {|row| $row.pid == {2} and $row.user_id == 0 }) and not \(is-admin) {
        sudo ps ($environment_flag) -o command -ww {2}
      } else {
        ^ps ($environment_flag) -o command -ww {2}
      }
        # TODO: This isn't perfect: if a variable's value
        # includes something that matches the environment variable name pattern
        # \([a-zA-Z_]+[a-zA-Z0-9_]*=), it will be considered the start
        # of a new variable. For this reason we shouldn't change the order of the
        # variables e.g. sorting
        | parse --regex '\(?sm)^\(?<name>[A-Z]+)=\(?<value>.*?)\(?=\\n[A-Z]+=|\\z)'
        | each { $'\($in.name)=│\($in.value)│' }
        | str join "\n"
        | less
    "

    let procs = (
      with-env {
        FZF_DEFAULT_COMMAND: $reload_command
        FZF_HINTS: 'ctrl+alt+r: refresh process list\nctrl+alt+o: view process output\nctrl+alt+e: view environment variables (at the time the process was launched)\nctrl+alt+t: trace process system calls'
      } {
        (
          fzf
            # only search on PID, PPID, and the command
            --nth '2,3,6..'
            --bind $'ctrl-alt-r:reload@($reload_command)@+first,ctrl-alt-e:execute@($environment_command)@,ctrl-alt-t:execute@($trace_command) o+e>| fzf --no-sort --no-preview@'
            --header-lines=1
            --prompt 'processes: '
            --preview $preview_command
            --no-hscroll
            --preview-window 'nowrap,75%'
            --delimiter "\t"
        )
      }
        | from tsv --noheaders
        | rename user_id pid ppid priority start_time command
    )

    if ($procs | is-empty) {
      return
    }

    let signal = (
      with-env { FZF_DEFAULT_COMMAND: '^kill -l' } {
        (
          fzf
            --header 'Select a signal to send or exit to print the PIDs'
            --prompt 'signals: '
            --preview ''
        )
      }
        | str trim --right --char "\n"
    )

    if ($signal | is-empty) {
      $procs | each { print $in.pid }
      return
    }

    print $"Sending SIG($signal) to the following processes: ($procs | get command | str join ', ')"
    if ($procs | any {|proc| $proc.user_id == 0}) and not (is-admin) {
      sudo kill --signal $signal ...($procs | get pid)
    } else {
      ^kill --signal $signal ...($procs | get pid)
    }
  }
  
  export def "widget grep" [] {
    grep_base 'pattern: ' $"rg --line-number --column --colors=path:none --no-heading --color=always -- {q} ($dir_placeholder)"
  }

  export def "widget grep-ast" [] {
    grep_base 'AST pattern: ' $"ast-grep --pattern {q} --json=stream ($dir_placeholder) | from json --objects | each { $\"\($in.file):\($in.range.start.line + 1):\($in.range.start.column + 1):\($in.lines | str replace \"\\n\" '␤')\" } | str join \"\\n\""
  }

  def grep_base [name: string, grep_command: string] {
    let grep_command = $grep_command | str replace $dir_placeholder '.'

    with-env {
      FZF_HINTS: 'alt+e: edit in neovim'
      FZF_DEFAULT_COMMAND: 'ignore'
    } {
      (
        fzf
          --disabled
          # We refresh-preview after executing vim in the event that the file gets modified by vim.
          --bind $"alt-e:execute\(nvim '+call cursor\({2},{3})' {1})+refresh-preview,change:first+reload:sleep 100ms; try { ($grep_command) }"
          --delimiter ':'
          --prompt $name
          --preview-window '+{2}/3,75%,~1'
          # the minus 2 prevents a weird line wrap issue
          #
          # wrap=never is there so the preview window is moved to the current line
          --preview r#'bat --style=header-filename --color always --wrap=never --paging=never --terminal-width (($env.FZF_PREVIEW_COLUMNS | into int) - 2) {1} --highlight-line {2}'#
      )
    }
      | lines
      | each { split row ":" | first }
      | each { to nuon }
      | str join " "
      | commandline edit --insert $in
  }
}

use widgets *
