#!/bin/bash

# Read input JSON from stdin
input=$(cat)

# Extract current working directory
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Change to the directory for git commands
cd "$cwd" 2>/dev/null || cd ~

# Color definitions (Catppuccin Mocha)
CYAN='\033[1;38;2;137;220;235m'     # sky      #89dceb
PURPLE='\033[1;38;2;203;166;247m'   # mauve    #cba6f7
GREEN='\033[1;38;2;166;227;161m'    # green    #a6e3a1
YELLOW='\033[1;38;2;249;226;175m'   # yellow   #f9e2af
RED='\033[1;38;2;243;139;168m'      # red      #f38ba8
BLUE='\033[1;38;2;137;180;250m'     # blue     #89b4fa
DIM_WHITE='\033[38;2;127;132;156m'  # overlay1 #7f849c
DIM_BAR='\033[38;2;88;91;112m'      # surface2 #585b70
RESET='\033[0m'

# Collect output segments; join with pipe separators at the end
segments=()
line3=""
line4=""

# ── Directory ───────────────────────────────────────────
dir="$cwd"

if git rev-parse --git-dir >/dev/null 2>&1; then
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$root" ]; then
        rel="${dir#$root}"
        name=$(basename "$root")
        if [ -z "$rel" ]; then
            dir="$name"
        else
            dir="$name$rel"
        fi
    fi
else
    dir=$(echo "$dir" | sed "s|^$HOME|~|" | awk -F/ '{
        if(NF<=4) print $0
        else print "…/"$(NF-3)"/"$(NF-2)"/"$(NF-1)"/"$NF
    }')
fi

dir_segment=$(printf "${CYAN}${dir}${RESET}")

# ── Git Branch & Status ────────────────────────────────
git_segment=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
        branch=$(git rev-parse --short HEAD 2>/dev/null)
    fi

    if [ -n "$branch" ]; then
        git_segment=$(printf "on ${PURPLE} ${branch}${RESET}")

        status=$(git status --porcelain 2>/dev/null)
        if [ -n "$status" ]; then
            modified=$(echo "$status" | grep -c '^ M' || true)
            staged=$(echo "$status" | grep -c '^[MARC]' || true)
            untracked=$(echo "$status" | grep -c '^??' || true)

            if [ "$modified" -gt 0 ]; then
                git_segment+=$(printf " ${YELLOW}!${modified}${RESET}")
            fi
            if [ "$staged" -gt 0 ]; then
                git_segment+=$(printf " ${GREEN}+${staged}${RESET}")
            fi
            if [ "$untracked" -gt 0 ]; then
                git_segment+=$(printf " ${BLUE}?${untracked}${RESET}")
            fi
        fi
    fi
fi

# Merge directory and git into one segment (they belong together visually)
if [ -n "$git_segment" ]; then
    segments+=("${dir_segment} ${git_segment}")
else
    segments+=("${dir_segment}")
fi

# ── Language Detection ──────────────────────────────────
if [ -f "package.json" ]; then
    segments+=("$(printf "${GREEN}⬢${RESET}")")
fi

# ── Line 2: Context bar with model name as label ─────
model=$(echo "$input" | jq -r '.model.display_name // empty')
model_label="${model:-ctx}"

# ── Helper: build a progress bar line ────────────────
# Usage: build_bar_line <percentage_int> <color> <label>
# Output: bar + right-aligned percent + label
build_bar_line() {
    local pct=$1 color=$2 label=$3
    local filled=$((pct / 5))
    local empty=$((20 - filled))
    local bar=""
    if [ "$filled" -gt 0 ]; then
        bar=$(printf "${color}%0.s█" $(seq 1 "$filled"))
    fi
    if [ "$empty" -gt 0 ]; then
        bar+=$(printf "${DIM_BAR}%0.s░" $(seq 1 "$empty"))
    fi
    printf "${bar} ${color}%3d%%${RESET} ${DIM_WHITE}%s${RESET}" "$pct" "$label"
}

pct_color() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then
        echo "$RED"
    elif [ "$pct" -ge 50 ]; then
        echo "$YELLOW"
    else
        echo "$GREEN"
    fi
}

# ── Context Window (progress bar) ─────────────────────
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used" ]; then
    used_int=$(printf "%.0f" "$used")
    ctx_color=$(pct_color "$used_int")
    line2="$(build_bar_line "$used_int" "$ctx_color" "$model_label")"
fi

# ── Rate Limits: 5-hour (line 3) ─────────────────────
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$five_h" ]; then
    five_h_int=$(printf "%.0f" "$five_h")
    five_h_color=$(pct_color "$five_h_int")
    line3="$(build_bar_line "$five_h_int" "$five_h_color" "5h")"
fi

# ── Rate Limits: 7-day (line 4) ──────────────────────
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$seven_d" ]; then
    seven_d_int=$(printf "%.0f" "$seven_d")
    seven_d_color=$(pct_color "$seven_d_int")
    line4="$(build_bar_line "$seven_d_int" "$seven_d_color" "7d")"
fi

# ── Claude Code Version ────────────────────────────────
cc_version=$(claude --version 2>/dev/null | head -1)
if [ -n "$cc_version" ]; then
    segments+=("$(printf "${DIM_WHITE}${cc_version}${RESET}")")
fi

# ── Join segments with pipe separators ──────────────────
separator=$(printf " ${DIM_WHITE}|${RESET} ")

output=""
for i in "${!segments[@]}"; do
    if [ "$i" -gt 0 ]; then
        output+="$separator"
    fi
    output+="${segments[$i]}"
done

echo "$output"
if [ -n "$line2" ]; then
    echo "$line2"
fi
if [ -n "$line3" ]; then
    echo "$line3"
fi
if [ -n "$line4" ]; then
    printf "%s" "$line4"
fi
