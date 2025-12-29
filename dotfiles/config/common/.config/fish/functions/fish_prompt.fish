function fish_prompt
    set last_status $status

    # Space before name
    printf " "

    # Name (yellow)
    set_color d79921
    printf " waris "

    # Arrow: green if OK, red if error
    if test $last_status -eq 0
        set_color 98971a
    else
        set_color cc241d
    end

    printf "❯ "

    set_color normal
end


