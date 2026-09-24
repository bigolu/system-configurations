$env.config.ls.use_ls_colors = false
$env.config.completions.use_ls_colors = false
$env.config.highlight_resolved_externals = true

$env.config.menus ++= [
  (
    $env.config.menus | where $it.name == help_menu | first | merge {
      style: {
        text: default
        selected_text: { attr: 'bold underline', fg: cyan }
        description_text: light_gray
      }
    }
  )
  (
    $env.config.menus | where $it.name == completion_menu | first | merge {
      style: {
        text: default
        selected_text: { attr: 'underline bold' }
        description_text: light_gray
        match_text: { fg: cyan }
        selected_match_text: { attr: 'underline bold', fg: cyan }
      }
    }
  )
  (
    $env.config.menus | where $it.name == ide_completion_menu | first | merge {
      style: {
        text: default
        selected_text: { attr: 'underline bold' }
        description_text: light_gray
        match_text: { fg: cyan }
        selected_match_text: { attr: 'underline bold', fg: cyan }
      }
    }
  )
]

$env.config.explore = {
  selected_cell: {bg: white, fg: black}
  highlight: {fg: black, bg: yellow}
  status: {
    info: {bg: black, fg: blue}
    success: {bg: black, fg: green}
    warn: {bg: black, fg: yellow}
    error: {bg: black, fg: red}
  }
}

$env.config.color_config = {
  binary: default
  binary_ascii_other: default
  binary_non_ascii: default
  binary_null_char: default
  binary_printable: default
  binary_whitespace: default
  block: default
  bool: default
  cell-path: default
  closure: default
  datetime: default
  duration: default
  empty: light_gray
  filesize: default
  float: default
  glob: default
  header: light_gray
  hints: light_gray_italic
  int: default
  leading_trailing_space_bg: default
  list: default
  nothing: default
  range: default
  record: default
  row_index: light_gray
  search_result: default
  selection: default
  selection_cursor: default
  semver: default
  semver-range: default
  separator: light_gray_dimmed
  shape_binary: default
  shape_block: default
  shape_bool: default
  shape_closure: default
  shape_custom: default
  shape_datetime: default
  shape_directory: default
  shape_external: default
  shape_external_resolved: default
  shape_externalarg: light_cyan
  shape_filepath: default
  shape_flag: default
  shape_float: default
  shape_garbage: red_underline
  shape_glob_interpolation: default
  shape_globpattern: default
  shape_int: default
  shape_internalcall: default
  shape_keyword: default
  shape_list: default
  shape_literal: default
  shape_match_pattern: default
  shape_matching_brackets: default
  shape_nothing: default
  shape_operator: default
  shape_pipe: default
  shape_range: default
  shape_raw_string: light_cyan
  shape_record: default
  shape_redirection: default
  shape_signature: default
  shape_string: light_cyan
  shape_string_interpolation: default
  shape_table: default
  shape_vardecl: default
  shape_variable: default
  string: light_cyan
}
