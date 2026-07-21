#!/usr/bin/env bash
# cupcakes-os-ui.sh — shared terminal UI primitives for Cupcakes OS tools.
# Source this file; do not execute it directly.
#
# All functions are prefixed with cupcakes_os_ to avoid collisions.
# Palette variables use the CUPCAKES_OS_ prefix.

# ── Version ───────────────────────────────────────────────────────────────────

_cupcakes_os_ui_resolve_version() {
    if [[ -n "${CUPCAKES_OS_VERSION:-}" ]]; then
        printf '%s' "$CUPCAKES_OS_VERSION"
        return
    fi
    if [[ -f /etc/cupcakes-os/VERSION ]]; then
        tr -d '[:space:]' < /etc/cupcakes-os/VERSION
        return
    fi
    printf '4.0'
}

CUPCAKES_OS_UI_VERSION="$(_cupcakes_os_ui_resolve_version)"

# ── Palette ───────────────────────────────────────────────────────────────────
# Ocean-themed palette — consistent across all Cupcakes OS terminal tools.

CUPCAKES_OS_BLUE=$'\033[38;5;33m'       # ocean blue   – borders, rules
CUPCAKES_OS_ACCENT=$'\033[38;5;87m'     # bright aqua  – selected state, highlights
CUPCAKES_OS_CYAN=$'\033[38;5;44m'       # sea teal     – steps, field values
CUPCAKES_OS_YELLOW=$'\033[38;5;222m'    # warm amber   – warnings
CUPCAKES_OS_WHITE=$'\033[1;97m'         # salt white   – titles, headings
CUPCAKES_OS_DIM=$'\033[38;5;242m'       # mist gray    – secondary text
CUPCAKES_OS_FAINT=$'\033[38;5;237m'     # abyss gray   – decorations, ultra-dim
CUPCAKES_OS_GREEN=$'\033[38;5;77m'      # kelp green   – success
CUPCAKES_OS_RED=$'\033[38;5;203m'       # coral red    – errors
CUPCAKES_OS_MAGENTA=$'\033[38;5;213m'   # sea rose     – mild highlights
CUPCAKES_OS_NC=$'\033[0m'               # reset

# ── Terminal helpers ──────────────────────────────────────────────────────────

cupcakes_os_cols() {
    local cols
    cols="$(tput cols 2>/dev/null || printf '80')"
    printf '%s' "${cols:-80}"
}

cupcakes_os_rows() {
    local rows
    rows="$(tput lines 2>/dev/null || printf '24')"
    printf '%s' "${rows:-24}"
}

_cupcakes_os_repeat() {
    local char="$1" count="$2" out=""
    while [[ "$count" -gt 0 ]]; do
        out+="$char"
        count=$((count - 1))
    done
    printf '%s' "$out"
}

cupcakes_os_trunc() {
    local str="$1" max="$2"
    if [[ "${#str}" -gt "$max" ]]; then
        printf '%s...' "${str:0:$((max - 3))}"
    else
        printf '%s' "$str"
    fi
}

# ── Visual primitives ─────────────────────────────────────────────────────────

cupcakes_os_rule() {
    local cols
    cols="$(cupcakes_os_cols)"
    printf '  %b' "$CUPCAKES_OS_FAINT"
    _cupcakes_os_repeat '─' $((cols - 4))
    printf '%b\n' "$CUPCAKES_OS_NC"
}

cupcakes_os_double_rule() {
    local cols
    cols="$(cupcakes_os_cols)"
    printf '  %b' "$CUPCAKES_OS_BLUE"
    _cupcakes_os_repeat '═' $((cols - 4))
    printf '%b\n' "$CUPCAKES_OS_NC"
}

cupcakes_os_wave_rule() {
    local cols
    cols="$(cupcakes_os_cols)"
    printf '  %b' "$CUPCAKES_OS_FAINT"
    _cupcakes_os_repeat '·' $((cols - 4))
    printf '%b\n' "$CUPCAKES_OS_NC"
}

# ── ASCII art logo ────────────────────────────────────────────────────────────

CUPCAKES_OS_ASCII_LOGO='
  %b▸▸%b %bCUPCAKES_OS OS%b  %b'"%s"'

  %b    ,ggg,                                                         _,gggggg,_          ,gg,%b
  %b   dP""8I   ,dPYb,                                              ,d8P""d8P"Y8b,       i8""8i %b
  %b  dP   88   IP'"'"'`Yb                                             ,d8'"'"'   Y8   "8b,dP    `8,,8'"'"' %b
  %b dP    88   I8  8I                                             d8'"'"'    `Ybaaad88P'"'"'     `88'"'"'  %b
  %b,8'"'"'    88   I8  8'"'"'                                             8P       `""""Y8       dP"8,%b
  %bd88888888   I8 dP         ,ggggg,     ,gggggg,    ,gggg,gg     8b            d8      dP'"'"' `8a %b
  %b,8"     88   I8dP   88gg  dP"  "Y8ggg  dP""""8I   dP"  "Y8I     Y8,          ,8P     dP'"'"'   `Yb%b
  %bdP"  ,8P      Y8   I8P    8I   i8'"'"'    ,8I   ,8'"'"'    8I  i8'"'"'    ,8I     `Y8,        ,8P'"'"' _ ,dP'"'"'     I8%b
  %bYb,_,dP       `8b,,d8b,  ,8I  ,d8,   ,d8'"'"'  ,dP     Y8,,d8,   ,d8b,     `Y8b,,__,,d8P'"'"'  "888,,____,dP%b
  %b "Y8P"         `Y88P'"'"'"Y88P'"'"'  P"Y8888P"    8P      `Y8P"Y8888P"`Y8       `"Y8888P'"'"'    a8P"Y88888P" %b
'

cupcakes_os_ascii_header() {
    local ver="${1:-$CUPCAKES_OS_UI_VERSION}"
    printf "$CUPCAKES_OS_ASCII_LOGO" \
        "$CUPCAKES_OS_ACCENT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_DIM" "$ver" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC"
}

# ── Brand header ──────────────────────────────────────────────────────────────

cupcakes_os_brand_header() {
    local cols inner left right pad max_left
    cols="$(cupcakes_os_cols)"
    inner=$((cols - 6))
    [[ $inner -lt 18 ]] && inner=18

    left="  ▸ CUPCAKES_OS OS"
    right="${CUPCAKES_OS_UI_VERSION}  "
    max_left=$((inner - ${#right} - 1))
    [[ $max_left -lt 6 ]] && max_left=6
    if [[ "${#left}" -gt "$max_left" ]]; then
        left="$(cupcakes_os_trunc "$left" "$max_left")"
    fi
    pad=$((inner - ${#left} - ${#right}))
    [[ $pad -lt 1 ]] && pad=1

    printf '%b╭' "$CUPCAKES_OS_BLUE"
    _cupcakes_os_repeat '─' "$inner"
    printf '╮%b\n' "$CUPCAKES_OS_NC"

    printf '%b│%b%b%s%b' "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_WHITE" "$left" "$CUPCAKES_OS_NC"
    printf '%*s' "$pad" ''
    printf '%b%s%b%b│%b\n' "$CUPCAKES_OS_DIM" "$right" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC"

    printf '%b╰' "$CUPCAKES_OS_BLUE"
    _cupcakes_os_repeat '─' "$inner"
    printf '╯%b\n' "$CUPCAKES_OS_NC"
}

# Compact brand line — fits in one row without a box.
cupcakes_os_brand_line() {
    local ver="${1:-$CUPCAKES_OS_UI_VERSION}"
    printf '%b▸%b %bCUPCAKES_OS OS%b  %b%s%b\n' \
        "$CUPCAKES_OS_ACCENT" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_DIM" "$ver" "$CUPCAKES_OS_NC"
}

# ── Card box ──────────────────────────────────────────────────────────────────

# Draw a bordered card with an optional title.
# Usage: cupcakes_os_card "Title" "content lines..."
# The card auto-wraps content within the terminal width.
cupcakes_os_card_start() {
    local title="${1:-}" cols inner
    cols="$(cupcakes_os_cols)"
    inner=$((cols - 6))
    [[ $inner -lt 20 ]] && inner=20
    [[ $inner -gt 70 ]] && inner=70

    printf '  %b╭─' "$CUPCAKES_OS_BLUE"
    if [[ -n "$title" ]]; then
        printf '%b %s ' "$CUPCAKES_OS_ACCENT" "$title"
        local remaining=$((inner - ${#title} - 3))
        [[ $remaining -lt 0 ]] && remaining=0
        _cupcakes_os_repeat '─' "$remaining"
    else
        _cupcakes_os_repeat '─' "$inner"
    fi
    printf '╮%b\n' "$CUPCAKES_OS_NC"
}

cupcakes_os_card_end() {
    local cols inner
    cols="$(cupcakes_os_cols)"
    inner=$((cols - 6))
    [[ $inner -lt 20 ]] && inner=20
    [[ $inner -gt 70 ]] && inner=70

    printf '  %b╰' "$CUPCAKES_OS_BLUE"
    _cupcakes_os_repeat '─' "$((inner + 1))"
    printf '╯%b\n' "$CUPCAKES_OS_NC"
}

# ── Step indicator ────────────────────────────────────────────────────────────

# Render a horizontal step flow:  ① Welcome  →  ② Names  →  ③ Locale ...
# Args: current_step total_steps step_names...
cupcakes_os_step_indicator() {
    local current="$1" total="$2"
    shift 2
    local names=("$@")
    local cols i label sep
    cols="$(cupcakes_os_cols)"

    for ((i = 0; i < total; i++)); do
        label="${names[$i]:-Step $((i+1))}"

        if [[ "$i" -lt "$current" ]]; then
            # completed
            printf '  %b✓%b %b%s%b' "$CUPCAKES_OS_GREEN" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_GREEN" "$label" "$CUPCAKES_OS_NC"
        elif [[ "$i" -eq "$current" ]]; then
            # active
            printf '  %b●%b %b%s%b' "$CUPCAKES_OS_ACCENT" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_WHITE" "$label" "$CUPCAKES_OS_NC"
        else
            # upcoming
            printf '  %b○%b %b%s%b' "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_DIM" "$label" "$CUPCAKES_OS_NC"
        fi

        if [[ "$i" -lt $((total - 1)) ]]; then
            if [[ "$i" -lt "$current" ]]; then
                sep=" %b──%b "
            elif [[ "$i" -eq "$current" ]]; then
                sep=" %b─▶%b "
            else
                sep=" %b──%b "
            fi
            printf "$sep" "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC"
        fi
    done
    printf '\n'
}

# ── Banner ────────────────────────────────────────────────────────────────────

# Print a banner without clearing the screen — for non-interactive CLI tools.
cupcakes_os_banner() {
    local title="${1:-}" subtitle="${2:-}"
    printf '\n'
    cupcakes_os_brand_header
    if [[ -n "$title" ]]; then
        printf '\n  %b%s%b\n' "$CUPCAKES_OS_WHITE" "$title" "$CUPCAKES_OS_NC"
    fi
    if [[ -n "$subtitle" ]]; then
        printf '  %b%s%b\n' "$CUPCAKES_OS_DIM" "$subtitle" "$CUPCAKES_OS_NC"
    fi
    printf '\n'
    cupcakes_os_rule
    printf '\n'
}

# Compact banner using the ASCII logo (only on wide terminals).
cupcakes_os_wide_banner() {
    local title="${1:-}" subtitle="${2:-}"
    local cols
    cols="$(cupcakes_os_cols)"

    printf '\n'
    if [[ "$cols" -ge 78 ]]; then
        cupcakes_os_ascii_header
        printf '\n'
        cupcakes_os_wave_rule
    else
        cupcakes_os_brand_header
    fi
    if [[ -n "$title" ]]; then
        printf '\n  %b%s%b\n' "$CUPCAKES_OS_WHITE" "$title" "$CUPCAKES_OS_NC"
    fi
    if [[ -n "$subtitle" ]]; then
        printf '  %b%s%b\n' "$CUPCAKES_OS_DIM" "$subtitle" "$CUPCAKES_OS_NC"
    fi
    printf '\n'
    cupcakes_os_rule
    printf '\n'
}

# ── Log line helpers ──────────────────────────────────────────────────────────

cupcakes_os_info() {
    printf '  %b·%b  %s\n' "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$1"
}

cupcakes_os_success() {
    printf '  %b✓%b  %b%s%b\n' "$CUPCAKES_OS_GREEN" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_GREEN" "$1" "$CUPCAKES_OS_NC"
}

cupcakes_os_warn() {
    printf '  %b!%b  %b%s%b\n' "$CUPCAKES_OS_YELLOW" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_YELLOW" "$1" "$CUPCAKES_OS_NC"
}

cupcakes_os_error() {
    printf '  %b✗%b  %b%s%b\n' "$CUPCAKES_OS_RED" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_RED" "$1" "$CUPCAKES_OS_NC" >&2
}

cupcakes_os_step() {
    printf '  %b▸%b  %s\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC" "$1"
}

cupcakes_os_dim_line() {
    printf '  %b%s%b\n' "$CUPCAKES_OS_DIM" "$1" "$CUPCAKES_OS_NC"
}

# ── Key-value row ─────────────────────────────────────────────────────────────

# Print a neatly aligned key-value pair.
# Usage: cupcakes_os_kv "key" "value" [key_width]
cupcakes_os_kv() {
    local key="$1" value="$2" key_width="${3:-18}"
    printf '  %b%-*s%b  %b%s%b\n' \
        "$CUPCAKES_OS_DIM" "$key_width" "$key" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_CYAN" "$value" "$CUPCAKES_OS_NC"
}

# Print a key-value with a dim/faint value (for read-only info).
cupcakes_os_kv_faint() {
    local key="$1" value="$2" key_width="${3:-18}"
    printf '  %b%-*s%b  %b%s%b\n' \
        "$CUPCAKES_OS_DIM" "$key_width" "$key" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_FAINT" "$value" "$CUPCAKES_OS_NC"
}

# ── Progress bar ──────────────────────────────────────────────────────────────

cupcakes_os_progress() {
    local percent="$1" cols width filled empty

    [[ $percent -lt 0 ]] && percent=0
    [[ $percent -gt 100 ]] && percent=100

    cols="$(cupcakes_os_cols)"
    width=$((cols - 12))
    [[ $width -lt 20 ]] && width=20
    [[ $width -gt 60 ]] && width=60

    filled=$((percent * width / 100))
    empty=$((width - filled))

    printf '  %b' "$CUPCAKES_OS_BLUE"
    _cupcakes_os_repeat '█' "$filled"
    printf '%b' "$CUPCAKES_OS_FAINT"
    _cupcakes_os_repeat '░' "$empty"
    printf '%b  %b%3d%%%b\n' "$CUPCAKES_OS_NC" "$CUPCAKES_OS_WHITE" "$percent" "$CUPCAKES_OS_NC"
}

# Smooth progress bar with gradient-like shading.
cupcakes_os_progress_smooth() {
    local percent="$1" cols width filled empty mid
    [[ $percent -lt 0 ]] && percent=0
    [[ $percent -gt 100 ]] && percent=100

    cols="$(cupcakes_os_cols)"
    width=$((cols - 12))
    [[ $width -lt 20 ]] && width=20
    [[ $width -gt 60 ]] && width=60

    filled=$((percent * width / 100))
    empty=$((width - filled))

    # Use accent color for the leading edge
    if [[ "$filled" -gt 1 ]]; then
        mid=$((filled - 1))
        printf '  %b' "$CUPCAKES_OS_BLUE"
        _cupcakes_os_repeat '█' "$mid"
        printf '%b█' "$CUPCAKES_OS_ACCENT"
    elif [[ "$filled" -eq 1 ]]; then
        printf '  %b█' "$CUPCAKES_OS_ACCENT"
    else
        printf '  %b' "$CUPCAKES_OS_BLUE"
    fi
    printf '%b' "$CUPCAKES_OS_FAINT"
    _cupcakes_os_repeat '░' "$empty"
    printf '%b  %b%3d%%%b\n' "$CUPCAKES_OS_NC" "$CUPCAKES_OS_WHITE" "$percent" "$CUPCAKES_OS_NC"
}

cupcakes_os_format_elapsed() {
    local secs="$1" m=0 h=0
    h=$((secs / 3600))
    m=$(((secs % 3600) / 60))
    secs=$((secs % 60))
    if [[ "$h" -gt 0 ]]; then
        printf '%02dh %02dm %02ds' "$h" "$m" "$secs"
    else
        printf '%02dm %02ds' "$m" "$secs"
    fi
}

# ── Spinner ───────────────────────────────────────────────────────────────────

# Simple one-frame spinner for non-blocking status.
# Usage: cupcakes_os_spinner_tick "message" [frame_number]
_cupcakes_os_spinner_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

cupcakes_os_spinner_tick() {
    local msg="$1" frame="${2:-0}"
    local idx=$((frame % ${#_cupcakes_os_spinner_frames[@]}))
    printf '\r  %b%s%b  %s' "$CUPCAKES_OS_ACCENT" "${_cupcakes_os_spinner_frames[$idx]}" "$CUPCAKES_OS_NC" "$msg"
}

# Clear the spinner line.
cupcakes_os_spinner_done() {
    printf '\r%*s\r' "$(cupcakes_os_cols)" ''
}

# ── Log tail ──────────────────────────────────────────────────────────────────

cupcakes_os_log_tail() {
    local logfile="$1" cols width line

    cols="$(cupcakes_os_cols)"
    width=$((cols - 6))
    [[ $width -lt 20 ]] && width=20

    if [[ ! -s "$logfile" ]]; then
        printf '  %bno output captured yet%b\n' "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC"
        return 0
    fi

    while IFS= read -r line; do
        printf '  %b%s%b\n' "$CUPCAKES_OS_FAINT" "$(cupcakes_os_trunc "$line" "$width")" "$CUPCAKES_OS_NC"
    done < <(tail -n 10 "$logfile")
}

# ── Checkbox menu helper ─────────────────────────────────────────────────────

# Render a checkbox-style option.
# Usage: cupcakes_os_checkbox "label" is_checked
cupcakes_os_checkbox() {
    local label="$1" checked="$2"
    if [[ "$checked" == "yes" || "$checked" == "true" ]]; then
        printf '  %b[✓]%b %b%s%b\n' "$CUPCAKES_OS_ACCENT" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_WHITE" "$label" "$CUPCAKES_OS_NC"
    else
        printf '  %b[ ]%b %b%s%b\n' "$CUPCAKES_OS_FAINT" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_DIM" "$label" "$CUPCAKES_OS_NC"
    fi
}
