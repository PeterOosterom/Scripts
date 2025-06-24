#!/bin/bash

### --- Configuration Section --- ###

# URLs for each Firefox window
URLS=(
    "https://www.mozilla.org"
    "https://example.com"
)

# Window geometry: width height x y (in pixels)
# Match index with URLS (same order)
WINDOWS=(
    "2560 1440 0 0"       # First window: top
    "2560 1440 0 1440"    # Second window: bottom
)

### --- End of Configuration --- ###

get_firefox_windows() {
    xdotool search --onlyvisible --class "firefox" 2>/dev/null
}

wait_for_new_window() {
    local old_windows=("$@")
    local timeout=10
    for ((i=0; i<timeout*2; i++)); do
        new_windows=($(get_firefox_windows))
        for win in "${new_windows[@]}"; do
            if [[ ! " ${old_windows[*]} " =~ " $win " ]]; then
                echo "$win"
                return
            fi
        done
        sleep 0.5
    done
    echo ""
}

fix_window() {
    local win=$1
    local width=$2
    local height=$3
    local x=$4
    local y=$5

    xdotool windowactivate "$win"
    sleep 0.2
    xdotool windowstate --remove MAXIMIZED_VERT --remove MAXIMIZED_HORZ "$win"
    sleep 0.2
    xdotool windowsize "$win" "$width" "$height"
    sleep 0.2
    xdotool windowmove "$win" "$x" "$y"
}

# Initial state
existing_windows=($(get_firefox_windows))

# Loop through all windows to open
for i in "${!URLS[@]}"; do
    url="${URLS[$i]}"
    read -r width height x y <<< "${WINDOWS[$i]}"

    firefox --new-window "$url" &
    win=$(wait_for_new_window "${existing_windows[@]}")
    if [[ -z "$win" ]]; then
        echo "❌ Failed to detect Firefox window $((i+1))"
        exit 1
    fi

    fix_window "$win" "$width" "$height" "$x" "$y"
    existing_windows+=("$win")
done
