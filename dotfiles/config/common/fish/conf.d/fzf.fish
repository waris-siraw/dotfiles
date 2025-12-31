# ===============================
# fzf configuration
# ===============================

set -Ux FZF_DEFAULT_OPTS "--height 40% --reverse --border"

# Ctrl+T → fuzzy file search
bind \ct 'commandline -i (fzf)'

# Alt+C → fuzzy directory jump
function __fzf_cd
    set dir (find . -type d 2>/dev/null | fzf)
    if test -n "$dir"
        cd $dir
    end
end
bind \ec '__fzf_cd'

