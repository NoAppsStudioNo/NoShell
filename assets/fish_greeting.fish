function fish_greeting
    echo -ne '\x1b[38;5;16m'  # Set colour to primary
    echo '        _   __     _____ __         ____ '
    echo '       / | / /___ / ___// /_  ___  / / / '
    echo '      /  |/ / __ \\\\__ \/ __ \/ _ \/ / /  '
    echo '     / /|  / /_/ /__/ / / / /  __/ / /   '
    echo '    /_/ |_/\____/____/_/ /_/\___/_/_/    '
    set_color normal
    command -v fastfetch &> /dev/null && fastfetch --key-padding-left 5
end
