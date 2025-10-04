#!/usr/bin/env bash
# vps-check.sh — Quick, human-readable health/config snapshot for Ubuntu VPS
# Usage: ./vps-check.sh [--no-color] [--quick]
#   --no-color  : disable ANSI colors
#   --quick     : skip slower checks (upgradeable packages, external IP)

set -euo pipefail

# ------------------------------- Styling ------------------------------------
USE_COLOR=1
QUICK=0
for arg in "$@"; do
  case "$arg" in
    --no-color) USE_COLOR=0 ;;
    --quick)    QUICK=1 ;;
  esac
done

if [[ -t 1 ]] && [[ $USE_COLOR -eq 1 ]]; then
  BOLD="$(tput bold 2>/dev/null || true)"
  DIM="$(tput dim 2>/dev/null || true)"
  RED="$(tput setaf 1 2>/dev/null || true)"
  GREEN="$(tput setaf 2 2>/dev/null || true)"
  YELLOW="$(tput setaf 3 2>/dev/null || true)"
  BLUE="$(tput setaf 4 2>/dev/null || true)"
  MAGENTA="$(tput setaf 5 2>/dev/null || true)"
  CYAN="$(tput setaf 6 2>/dev/null || true)"
  RESET="$(tput sgr0 2>/dev/null || true)"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; RESET=""
fi

hr() { printf "${DIM}──────────────────────────────────────────────────────────────────────${RESET}\n"; }
title() { printf "\n${BOLD}${1}${RESET}\n"; hr; }
subtitle() { printf "${DIM}%s${RESET}\n" "$1"; }
kv() {
  local k="$1"; shift
  local v="$*"
  printf "  ${BOLD}%-20s${RESET} %s\n" "$k" "$v"
}
warn() { printf "${YELLOW}⚠ %s${RESET}\n" "$*"; }
ok()   { printf "${GREEN}✔ %s${RESET}\n" "$*"; }
err()  { printf "${RED}✘ %s${RESET}\n" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Small helper to run command or show N/A
run_or_na() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    kv "$desc" "$("$@")"
  else
    kv "$desc" "N/A"
  fi
}

# ------------------------------ Header --------------------------------------
clear 2>/dev/null || true
printf "${BOLD}🧭 VPS Quick Check${RESET}  ${DIM}(Ubuntu-focused)${RESET}\n"
hr
kv "Host"    "$(hostname -f 2>/dev/null || hostname)"
kv "Time"    "$(date -Is)"
kv "Uptime"  "$(uptime -p 2>/dev/null || cut -d, -f1 /proc/uptime 2>/dev/null || echo "unknown")"
kv "User"    "$USER"
kv "TTY"     "${TERM:-unknown}"

# --------------------------- System Information ------------------------------
title "🧩 System Information"
# OS / Release
if have lsb_release; then
  kv "OS" "$(lsb_release -ds)"
else
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    kv "OS" "${PRETTY_NAME:-Unknown}"
  else
    kv "OS" "Unknown"
  fi
fi
run_or_na "Kernel" uname -r
run_or_na "Architecture" uname -m

# CPU
if have lscpu; then
  model=$(lscpu | awk -F: '/Model name/ {print $2}' | sed 's/^ *//')
  cores=$(lscpu | awk -F: '/^CPU\(s\)/{print $2}' | sed 's/^ *//')
  kv "CPU" "${model:-Unknown}"
  kv "CPU Cores" "${cores:-Unknown}"
else
  kv "CPU" "$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//' || echo N/A)"
  kv "CPU Cores" "$(nproc 2>/dev/null || echo N/A)"
fi

# Virtualization hint
virt="Unknown"
if [[ -r /proc/1/cgroup ]]; then
  if grep -qi docker /proc/1/cgroup; then virt="Docker container"; fi
fi
if have systemd-detect-virt; then
  virt=$(systemd-detect-virt 2>/dev/null || echo "$virt")
fi
kv "Virtualization" "$virt"

# ------------------------------ Memory --------------------------------------
title "🧠 Memory & Swap"
if have free; then
  # Human readable line
  memline=$(free -h | awk '/^Mem:/ {print $2" total, "$3" used, "$4" free, "$7" avail"}')
  kv "Memory" "$memline"
  swapline=$(free -h | awk '/^Swap:/ {print $2" total, "$3" used, "$4" free"}')
  kv "Swap" "$swapline"
else
  kv "Memory" "free(1) not available"
fi

# ------------------------------ Storage -------------------------------------
title "💾 Storage"
if have lsblk; then
  subtitle "Block devices (lsblk):"
  lsblk -o NAME,TYPE,FSTYPE,SIZE,RM,RO,MOUNTPOINTS | sed 's/^/  /'
else
  warn "lsblk not found."
fi

echo
subtitle "Filesystem usage (df -hT):"
df -hT -x tmpfs -x devtmpfs | sed 's/^/  /'

# Check inode pressure
echo
subtitle "Inode usage (df -i):"
df -i -x tmpfs -x devtmpfs | sed 's/^/  /'

# ------------------------------ Disks I/O -----------------------------------
title "📈 I/O & Performance (snapshot)"
if have iostat; then
  subtitle "iostat (1 sample over 1s)…"
  iostat -xz 1 1 | sed 's/^/  /'
else
  subtitle "vmstat (1 sample over 1s)…"
  if have vmstat; then
    vmstat 1 2 | tail -n1 | sed 's/^/  /'
  else
    warn "Neither iostat nor vmstat found (install 'sysstat' for iostat)."
  fi
fi

# ------------------------------- Network ------------------------------------
title "🌐 Network"
if have ip; then
  subtitle "Interfaces (ip -br a):"
  ip -br a | sed 's/^/  /'
else
  warn "ip command not found."
fi

echo
subtitle "Routes:"
if have ip; then
  ip route | sed 's/^/  /'
else
  route -n 2>/dev/null | sed 's/^/  /' || true
fi

# DNS
echo
subtitle "DNS resolvers:"
if have resolvectl; then
  resolvectl status 2>/dev/null | sed -n '1,120p' | sed 's/^/  /'
elif [[ -r /etc/resolv.conf ]]; then
  sed 's/^/  /' /etc/resolv.conf
else
  warn "No DNS info available."
fi

# External IP (skip on --quick)
if [[ $QUICK -eq 0 ]]; then
  echo
  subtitle "External/Public IP:"
  if have curl; then
    kv "IPv4" "$(curl -4 -m 4 -s https://ifconfig.me || echo N/A)"
    kv "IPv6" "$(curl -6 -m 4 -s https://ifconfig.me || echo N/A)"
  elif have wget; then
    kv "IPv4" "$(wget -qO- --timeout=4 -4 https://ifconfig.me || echo N/A)"
    kv "IPv6" "$(wget -qO- --timeout=4 -6 https://ifconfig.me || echo N/A)"
  else
    warn "Install curl or wget to fetch public IP."
  fi
fi

# ------------------------------ Security ------------------------------------
title "🔐 Security & Access"
# Open ports
if have ss; then
  subtitle "Listening sockets (ss -tulpen):"
  ss -tulpen | sed 's/^/  /'
elif have netstat; then
  subtitle "Listening sockets (netstat -tulpen):"
  sudo netstat -tulpen | sed 's/^/  /' || netstat -tulpen | sed 's/^/  /'
else
  warn "Neither ss nor netstat available."
fi

echo
# UFW status (Ubuntu firewall)
if have ufw; then
  subtitle "UFW:"
  ufw status verbose | sed 's/^/  /'
else
  subtitle "UFW:"
  echo "  Not installed (sudo apt install ufw)" 
fi

# SSH basics
echo
subtitle "SSH daemon basics:"
sshd_cfg="/etc/ssh/sshd_config"
kv "sshd_config" "$sshd_cfg"
if [[ -r "$sshd_cfg" ]]; then
  pword=$(grep -Ei '^\s*PasswordAuthentication\s+' "$sshd_cfg" | tail -n1 | awk '{print $2}')
  rootl=$(grep -Ei '^\s*PermitRootLogin\s+' "$sshd_cfg" | tail -n1 | awk '{print $2}')
  kv "PasswordAuthentication" "${pword:-(default)}"
  kv "PermitRootLogin" "${rootl:-(default)}"
else
  warn "Cannot read $sshd_cfg (need sudo?)."
fi

# ------------------------------ Services ------------------------------------
title "🧷 Services"
if have systemctl; then
  kv "Init system" "systemd"
  echo
  subtitle "Running services:"
  systemctl list-units --type=service --state=running --no-pager | sed 's/^/  /'
  echo
  subtitle "Failed services:"
  systemctl --failed --no-pager | sed 's/^/  /'
else
  kv "Init system" "Unknown (systemctl not found)"
fi

# --------------------------- Packages & Updates ------------------------------
title "📦 Packages & Updates"
if have apt; then
  kv "APT source list" "/etc/apt/sources.list.d + /etc/apt/sources.list"
  if [[ $QUICK -eq 0 ]]; then
    subtitle "Upgradeable packages (apt list --upgradeable):"
    apt list --upgradeable 2>/dev/null | sed 's/^/  /' || warn "Failed to list upgradeable packages."
  else
    subtitle "Upgradeable packages:"
    echo "  Skipped (use without --quick to check)"
  fi
else
  warn "apt not available."
fi

# --------------------------- Log-in & Users ----------------------------------
title "👥 Sessions & Users"
run_or_na "Who is logged in" who
run_or_na "Last logins" last -n 5

# --------------------------- Disk Health (basic) -----------------------------
title "🩺 Basic Disk Health"
if have lsblk && have awk; then
  # Trim status where applicable (SSD)
  subtitle "TRIM support (fstrim -n):"
  if have fstrim; then
    if sudo -n true 2>/dev/null; then
      sudo fstrim -n -a 2>/dev/null | sed 's/^/  /' || warn "fstrim ran with warnings."
    else
      warn "Run with sudo to check TRIM across all mounts (sudo fstrim -n -a)."
    fi
  else
    warn "fstrim not installed (sudo apt install util-linux)."
  fi
else
  warn "Skipping TRIM check."
fi

# ------------------------------ Footer --------------------------------------
hr
printf "${BOLD}Done.${RESET} Pro tip: run with ${BOLD}--quick${RESET} for a lighter pass, or ${BOLD}--no-color${RESET} for plain text.\n"
echo
