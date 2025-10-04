# sh — Self-Hosted Script Endpoints

Serve shell scripts via GitHub Pages + custom domain for easy remote execution.

## 🚀 Usage

### Option 1: Direct execution (always latest version)
```bash
# VPS health check
bash <(curl -fsSL https://sh.youyoubilly.com/vps-check.sh)

# Quick mode (skip slow checks)
bash <(curl -fsSL https://sh.youyoubilly.com/vps-check.sh) --quick
```

### Option 2: Install as command (deploy once, use anytime)
```bash
# Install vpscheck command on this VPS
bash <(curl -fsSL https://sh.youyoubilly.com/install-vpscheck.sh)

# Then use the simple command
vpscheck
vpscheck --quick
vpscheck --no-color
```

## 📁 Scripts

- `vps-check.sh` - Comprehensive VPS health and configuration check
- `install-vpscheck.sh` - Installer to deploy `vpscheck` command locally

## 🔧 Setup

- **Repository**: [youyoubilly/sh](https://github.com/youyoubilly/sh)
- **Domain**: `sh.youyoubilly.com` (GitHub Pages + custom domain)
- **Auto-updates**: Push to `main` branch → instantly available online