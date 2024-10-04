#!/usr/bin/env fish

if not test "$TERM_PROGRAM" = WezTerm
    or not type --query wezterm
    fzf $argv
    return $status
end

wezterm cli zoom-pane --zoom

fzf $argv
set _fzf_return_value $status

wezterm cli zoom-pane --unzoom

return $_fzf_return_value
