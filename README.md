# sh — Self-Hosted Script Endpoints

Serve shell scripts via GitHub Pages + custom domain for easy remote execution.

## 🚀 Usage

```bash
# VPS health check
bash <(curl -fsSL https://sh.youyoubilly.com/vps-check.sh)

# Quick mode (skip slow checks)
bash <(curl -fsSL https://sh.youyoubilly.com/vps-check.sh) --quick
```

## 📁 Scripts

- `vps-check.sh` - Comprehensive VPS health and configuration check

## 🔧 Setup

- **Repository**: [youyoubilly/sh](https://github.com/youyoubilly/sh)
- **Domain**: `sh.youyoubilly.com` (GitHub Pages + custom domain)
- **Auto-updates**: Push to `main` branch → instantly available online