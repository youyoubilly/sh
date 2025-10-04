#!/usr/bin/env bash
# install-vpscheck.sh — Install vpscheck command on this VPS
# Usage: bash <(curl -fsSL https://sh.youyoubilly.com/install-vpscheck.sh)

set -euo pipefail

echo "🚀 Installing vpscheck command..."

# Create the vpscheck script
sudo tee /usr/local/bin/vpscheck > /dev/null << 'EOF'
#!/usr/bin/env bash
# vpscheck — VPS health check command
# Installed by install-vpscheck.sh from sh.youyoubilly.com

exec bash <(curl -fsSL https://sh.youyoubilly.com/vps-check.sh) "$@"
EOF

# Make it executable
sudo chmod +x /usr/local/bin/vpscheck

echo "✅ vpscheck command installed successfully!"
echo ""
echo "You can now run:"
echo "  vpscheck          # Full VPS health check"
echo "  vpscheck --quick  # Quick check (skip slow operations)"
echo "  vpscheck --no-color # Plain text output"
echo ""
echo "The command will always fetch the latest version from sh.youyoubilly.com"
