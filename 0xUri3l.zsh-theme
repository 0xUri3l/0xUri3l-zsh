#Author : 0xUr!3l <Greyd4rk> (https://github.com/0xUri3l)

# Load and configure vcs_info
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git # Enable git support
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr '%F{yellow}%f' # Icon for unstaged changes (Warning sign)
zstyle ':vcs_info:*' stagedstr '%F{green}%f'   # Icon for staged changes (Plus sign, can also be a checkmark)
zstyle ':vcs_info:*' NV_NVCSCOLUMNS '' # Clear default vcs_info output
zstyle ':vcs_info:*' actionformats '[%F{cyan}%b%f%F{yellow}%a%f%F{green}%c%f]' # Branch, action, changes
zstyle ':vcs_info:*' formats       '[%F{cyan} %b%f%u%c]' # Default format: Branch icon, branch name, unstaged, staged
zstyle ':vcs_info:*' branchformat  '%b' # Just the branch name for actionformats

# Customizations for ahead/behind/diverged/unmerged
zstyle ':vcs_info:git:*' GITSCOLUMNS '' # Clear default git specific output
zstyle ':vcs_info:git:*' formats       '[%F{cyan} %b%f %F{magenta}%m%f%u%c%F{red}%p%f]' # Branch icon, branch, merge status, unstaged, staged, stashes
zstyle ':vcs_info:git:*' actionformats '[%F{cyan} %b%f %F{magenta}%m%f %F{yellow}%a%f%u%c%F{red}%p%f]' # Branch icon, branch, merge status, action, unstaged, staged, stashes
zstyle ':vcs_info:git:*' nvcsformats   '' # No VCS

# Icons for ahead, behind, diverged
zstyle ':vcs_info:git*:' check-for-staged-changes true
zstyle ':vcs_info:git*:' check-for-unstaged-changes true
zstyle ':vcs_info:git*:' stagedstr    '%F{green}S%f' # Placeholder, we can use icons if preferred
zstyle ':vcs_info:git*:' unstagedstr  '%F{yellow}U%f' # Placeholder

# More specific git states using hooks
# This function will be called by vcs_info to format the git part
# It allows for more complex logic for icons
git_format_with_icons() {
    local git_info
    local ahead_icon=" %F{green} %f"      # Ahead arrow
    local behind_icon=" %F{red} %f"       # Behind arrow
    local diverged_icon=" %F{magenta}󰀬%f"  # Diverged icon
    local unmerged_icon=" %F{red}%f"      # Unmerged/Conflict (Cross mark)
    local stash_icon=" %F{blue}%f"       # Stash icon (Box)
    local clean_icon=""              # No icon if clean, or a checkmark like %F{green}%f

    # Check for stashes
    if [[ -n $(git stash list 2>/dev/null) ]]; then
        git_info+="${stash_icon}"
    fi

    # Check for unmerged files (conflicts)
    if [[ -n $(git diff --name-only --diff-filter=U 2>/dev/null) ]]; then
        git_info+="${unmerged_icon}"
    fi
    
    # Ahead, Behind, Diverged
    local ahead_commits=$(git rev-list --count @{u}..HEAD 2>/dev/null)
    local behind_commits=$(git rev-list --count HEAD..@{u} 2>/dev/null)

    if (( ahead_commits > 0 && behind_commits > 0 )); then
        git_info+="${diverged_icon}${ahead_commits}${behind_icon}${behind_commits}"
    elif (( ahead_commits > 0 )); then
        git_info+="${ahead_icon}${ahead_commits}"
    elif (( behind_commits > 0 )); then
        git_info+="${behind_icon}${behind_commits}"
    elif [[ -z "$git_info" && -z "${vcs_info_msg_0_}" && -z "${vcs_info_msg_1_}" ]]; then # If no other status, and clean
        # git_info+="${clean_icon}" # Optional: icon for clean state
        : # Do nothing, keep it clean
    fi
    
    # Add staged/unstaged info (using vcs_info's built-in strings for these)
    # The %u and %c in formats will pick these up
    # vcs_info_msg_0_ is for unstaged, vcs_info_msg_1_ is for staged
    # We can augment them here if needed, e.g. add counts
    
    echo -n "$git_info"
}
# Register the hook function to extend default vcs_info output
zstyle ':vcs_info:git*:' formats       '[%F{cyan} %b%f${vcs_info_hook_git_status}%u%c]'
zstyle ':vcs_info:git*:' actionformats '[%F{cyan} %b%f${vcs_info_hook_git_status} %F{yellow}%a%f%u%c]'
zstyle ':vcs_info:*' enable git # ensure git is primary
zstyle ':vcs_info:git*:*' misc GITSCOLUMNS # clear some defaults
zstyle ':vcs_info:git*:*' nvcsformats ''
zstyle ':vcs_info:git*:' hooks git_status # Hook name
zstyle ':vcs_info:git*:' use-simple true # Important for hooks
zstyle ':vcs_info:git*:' stagedstr    '%F{green}%f'  # Staged (Plus or Check)
zstyle ':vcs_info:git*:' unstagedstr  '%F{yellow}%f' # Unstaged (Pencil/Edit)

# Function to get virtualenv info
get_virtualenv_info() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        local venv=$(basename "$VIRTUAL_ENV")
        echo "%F{blue} ${venv}%f"
    fi
}

# Function to calculate command execution time
preexec() {
    cmd_timestamp=$SECONDS
}

precmd() {
    [[ -n "$cmd_timestamp" ]] || return
    local cmd_duration=$(($SECONDS - $cmd_timestamp))
    unset cmd_timestamp
    
    if [[ $cmd_duration -ge 5 ]]; then
        # Format duration nicely
        if [[ $cmd_duration -ge 60 ]]; then
            local minutes=$((cmd_duration / 60))
            local seconds=$((cmd_duration % 60))
            cmd_exec_time="${minutes}m${seconds}s"
        else
            cmd_exec_time="${cmd_duration}s"
        fi
        export cmd_exec_time
    else
        unset cmd_exec_time
    fi
    
    # Call vcs_info in the precmd function for Git status
    vcs_info
}

# Function to get battery percentage and status
get_battery_info() {
    local percentage
    local battery_status
    local bat_path
    local status_icon
    local color_code

    # Determine which battery is available
    if [[ -f /sys/class/power_supply/BAT0/capacity ]]; then
        bat_path="/sys/class/power_supply/BAT0"
    elif [[ -f /sys/class/power_supply/BAT1/capacity ]]; then
        bat_path="/sys/class/power_supply/BAT1"
    fi

    # Try to get battery percentage and status
    if [[ -n "$bat_path" ]]; then
        percentage=$(cat "$bat_path/capacity")
        if [[ -f "$bat_path/status" ]]; then
            battery_status=$(cat "$bat_path/status")
        fi
    else
        # Fallback to upower if available
        if command -v upower &> /dev/null; then
            local battery_path=$(upower -e | grep 'BAT')
            if [[ -n "$battery_path" ]]; then
                percentage=$(upower -i "$battery_path" | awk '/percentage:/ {print int($2)}')
                battery_status=$(upower -i "$battery_path" | awk '/state:/ {print $2}')
            fi
        fi
    fi

    if [[ -z "$percentage" ]]; then
        echo "%F{red} N/A%f" # Error icon and N/A
        return
    fi

    # Determine icon and color based on percentage
    if (( percentage > 75 )); then
        status_icon="" # Full
        color_code="%F{green}"
    elif (( percentage > 50 )); then
        status_icon="" # Three-quarters
        color_code="%F{yellow}"
    elif (( percentage > 25 )); then
        status_icon="" # Half
        color_code="%F{yellow}"
    elif (( percentage > 10 )); then
        status_icon="" # Quarter
        color_code="%F{red}"
    else
        status_icon="" # Empty
        color_code="%F{red}"
    fi

    # Add charging indicator if the battery is charging
    local charging_indicator=""
    if [[ "$battery_status" == "Charging" || "$battery_status" == "charging" ]]; then
        charging_indicator=" ⚡" 
    fi

    echo "${color_code}${status_icon}${charging_indicator} ${percentage}%%%f"
}

PROMPT='
 ┌[%F{magenta} %~%f 
┌└%F{yellow} $USER%f💀🚬%F{yellow}%m%f %F{white}⮞  %f%F{cyan}$(get_battery_info)%f %F{white}⮞  %f%F{green}$(get_ip_address)%f$( [[ -n "$vcs_info_msg_0_" ]] && echo " %F{white}•  %f$(vcs_info_wrapper)" )
└➤ '

# Show execution time of long-running commands
RPROMPT='$([ -n "$cmd_exec_time" ] && echo "[%F{yellow}↱ ${cmd_exec_time}%f]")'

# Wrapper for vcs_info
vcs_info_wrapper() {
  if [[ -n "$vcs_info_msg_0_" ]]; then
    # Extraire le nom de la branche et les indicateurs d'état
    # We need the raw branch name for comparison
    local raw_branch_name=$(echo "$vcs_info_msg_0_" | command grep -oP '(?<= |🌱 |🪵 )[^ %]+' || echo "") # Adjust grep for multiple icons
    local git_status=$(echo "$vcs_info_msg_0_" | sed -E 's/.*( |🌱 |🪵 )[^ ]+ ?(.*)/\2/') # Adjust sed for multiple icons

    local branch_icon_color branch_icon
    # Check for master or main branch
    if [[ "$raw_branch_name" == "master" || "$raw_branch_name" == "main" ]]; then
      branch_icon_color="%F{green}"
      branch_icon="🪵"
    else # Other branches
      branch_icon_color="%F{cyan}"
      branch_icon="🌱"
    fi

    # Afficher l'icône (correcte), la branche en vert, et le status
    echo "${branch_icon_color}${branch_icon}%f %F{green}${raw_branch_name}%f ${git_status}"
  fi
}

get_ip_address() {
  local found=0
  local ips=()
  while IFS= read -r line; do
    local iface=$(echo "$line" | awk '{print $2}')
    local ip=$(echo "$line" | awk '{print $4}' | cut -d'/' -f1)
    # Vérifier si l'interface est strictement en état UP
    local linkinfo=$(ip -o link show "$iface")
    if [[ "$iface" != "lo" && -n "$ip" && "$linkinfo" == *"state UP"* ]]; then
      local icon=""
      local color="%F{cyan}"
      if [[ "$iface" == tun* || "$iface" == tap* || "$iface" == wg* || "$iface" == *vpn* || "$iface" == *VPN* || "$linkinfo" == *POINTOPOINT* ]]; then
        icon="🛡️"
        color="%F{magenta}"
      elif [[ "$iface" == eth* || "$iface" == enp* ]]; then
        icon=""
      elif [[ "$iface" == wlan* || "$iface" == wlp* || "$iface" == wlo* ]]; then
        icon="🔌"
      else
        icon="" # Par défaut Ethernet
      fi
      ips+=("${color}${icon} ${ip}%f")
      found=1
    fi
  done < <(ip -o -4 addr show)
  if (( found )); then
    printf "%s " "${ips[@]}"
    echo
  else
    echo "%F{red}%f"
  fi
}
