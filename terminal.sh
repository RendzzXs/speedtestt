# ============================================
#   🖥️  PRO CLEAN TERMINAL - VPS EDITION
# ============================================

# ---------- Clear Otomatis (Hybrid - aman) ----------
clear_if_dirty() {
    local current=$(history 1 | awk '{print $1}')
    if [ -n "$LAST_HIST" ] && [ "$current" -gt "$LAST_HIST" ]; then
        LAST_HIST=$current
        clear
    else
        LAST_HIST=$current
    fi
}
PROMPT_COMMAND="clear_if_dirty"

# ---------- History ----------
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T "
shopt -s histappend
shopt -s checkwinsize

# ---------- Auto-completion ----------
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous on"
bind "set menu-complete-display-prefix on"

# ---------- Warna ----------
RESET="\[\033[0m\]"
BOLD="\[\033[1m\]"
DIM="\[\033[2m\]"
BRED="\[\033[1;31m\]"
BGREEN="\[\033[1;32m\]"
BYELLOW="\[\033[1;33m\]"
BBLUE="\[\033[1;34m\]"
BMAGENTA="\[\033[1;35m\]"
BCYAN="\[\033[1;36m\]"
BWHITE="\[\033[1;37m\]"

# ---------- Git Branch ----------
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# ---------- Root vs User ----------
if [ "$(id -u)" -eq 0 ]; then
    USER_COLOR="${BRED}"; ICON="⚡"
else
    USER_COLOR="${BGREEN}"; ICON="❯"
fi

# ---------- PS1 ----------
PS1="\n${DIM}┌─[${RESET}${BCYAN}\h${RESET}${DIM}]─[${RESET}${BMAGENTA}\t${RESET}${DIM}]─[${RESET}${BBLUE}\w${RESET}${DIM}]${RESET}${BYELLOW}\$(parse_git_branch)${RESET}\n"
PS1+="${DIM}└─${RESET}${USER_COLOR}${ICON} \u${RESET} ${BWHITE}❯${RESET} "

# ---------- Alias ----------
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lah --color=auto --group-directories-first'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias h='history'
alias c='clear'
alias ports='netstat -tulanp 2>/dev/null || ss -tulanp'
alias mem='free -h'
alias disk='df -h'
alias cpu='top -bn1 | head -20'
alias myip='curl -s ifconfig.me && echo'
alias update='apt update && apt upgrade -y'
alias reload='source ~/.bashrc && echo "✅ Reloaded!"'

# ---------- Welcome Banner ----------
if [ -z "$BANNER_SHOWN" ]; then
    export BANNER_SHOWN=1
    echo -e "${BCYAN}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║   🚀 VPS TERMINAL - READY TO ROCK    ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${DIM}Host:${RESET} ${BWHITE}$(hostname)${RESET}"
    echo -e "  ${DIM}User:${RESET} ${BWHITE}$(whoami)${RESET}"
    echo -e "  ${DIM}IP  :${RESET} ${BWHITE}$(curl -s --max-time 2 ifconfig.me 2>/dev/null || echo 'N/A')${RESET}"
    echo -e "  ${DIM}Date:${RESET} ${BWHITE}$(date '+%A, %d %B %Y - %H:%M')${RESET}"
    echo ""
fi
