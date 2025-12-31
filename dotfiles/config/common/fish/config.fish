# Fish-config
if status is-interactive
    atuin init fish | source
end
# Disable the default fish greeting message
set -g fish_greeting ""

set -gx PATH /usr/bin /bin $PATH
set -gx EDITOR nvim
set -gx VISUAL nvim

# ===============================
# Gruvbox Dark colors
# ===============================
set -g fish_color_normal        ebdbb2
set -g fish_color_command       d79921
set -g fish_color_param         ebdbb2
set -g fish_color_keyword       d79921
set -g fish_color_quote         b8bb26
set -g fish_color_redirection   d79921
set -g fish_color_end           d79921
set -g fish_color_error         cc241d
set -g fish_color_comment       928374
set -g fish_color_selection     --background=3c3836
set -g fish_color_search_match  --background=3c3836
set -g fish_color_operator      98971a
set -g fish_color_escape        689d6a
set -g fish_color_autosuggestion 504945
set -g fish_color_cwd           98971a



