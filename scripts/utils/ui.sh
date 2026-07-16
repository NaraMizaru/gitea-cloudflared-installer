#!/bin/bash

# ANSI Color Codes
CLR_BLUE="\e[38;5;39m"
CLR_CYAN="\e[38;5;81m"
CLR_GREEN="\e[32;1m"
CLR_RED="\e[31;1m"
CLR_GRAY="\e[38;5;244m"
CLR_RESET="\e[0m"

print_header() {
    clear
    echo -e "${CLR_BLUE}===============================================${CLR_RESET}"
    echo -e "${CLR_CYAN}      Gitea + Cloudflared Auto Installer       ${CLR_RESET}"
    echo -e "${CLR_BLUE}===============================================${CLR_RESET}"
    echo ""
}

run_with_spinner() {
    local msg="$1"
    shift
    
    # Run the command in the background, redirecting stdout and stderr to the log
    "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # Spinner characters (Braille)
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local delay=0.1
    
    # Hide cursor
    echo -ne "\e[?25l"
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${CLR_BLUE}%c${CLR_RESET} %s... " "$spinstr" "$msg"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    
    # Show cursor
    echo -ne "\e[?25h"
    
    # Wait for the background process to complete and grab exit code
    wait "$pid"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Green checkmark and success message
        printf "\r\e[32m✔\e[0m %s ${CLR_GREEN}[SUKSES]${CLR_RESET}\e[K\n" "$msg"
    else
        # Red cross and error message
        printf "\r\e[31m✘\e[0m %s ${CLR_RED}[GAGAL]${CLR_RESET}\e[K\n" "$msg"
        echo -e "\n${CLR_RED}ERROR: Jalankan dibatalkan karena kesalahan.${CLR_RESET}"
        echo -e "Detail error dapat dilihat di berkas log: ${CLR_BLUE}$LOG_FILE${CLR_RESET}"
        echo -e "${CLR_GRAY}--------------------------------------------------${CLR_RESET}"
        tail -n 15 "$LOG_FILE" | sed 's/^/  /'
        echo -e "${CLR_GRAY}--------------------------------------------------${CLR_RESET}"
        echo ""
        exit 1
    fi
}
