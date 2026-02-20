#!/bin/bash
#
# Installation script for zos-shell-utilities
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash -s v1.0.0
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/install.sh | bash -s main
#

set -e

# Configuration
REPO_OWNER="${REPO_OWNER:-andrewhughes}"
REPO_NAME="${REPO_NAME:-zos-shell}"
VERSION="${1:-latest}"
TOOLS=("inuse" "logr_manager")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}$1${NC}"
}

warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

info() {
    echo "$1"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required but not installed. Please install curl and try again."
    fi
}

# Detect installation directory
detect_install_dir() {
    if [ -n "$INSTALL_DIR" ]; then
        # User specified directory
        if [ ! -d "$INSTALL_DIR" ]; then
            mkdir -p "$INSTALL_DIR" 2>/dev/null || error "Cannot create directory: $INSTALL_DIR"
        fi
        if [ ! -w "$INSTALL_DIR" ]; then
            error "No write permission for directory: $INSTALL_DIR"
        fi
        echo "$INSTALL_DIR"
        return
    fi

    # Try $HOME/bin first
    if [ -d "$HOME/bin" ] && [ -w "$HOME/bin" ]; then
        echo "$HOME/bin"
        return
    fi

    # Try to create $HOME/bin
    if mkdir -p "$HOME/bin" 2>/dev/null; then
        echo "$HOME/bin"
        return
    fi

    # Fall back to /usr/local/bin
    if [ -w "/usr/local/bin" ]; then
        echo "/usr/local/bin"
        return
    fi

    error "Cannot find writable installation directory. Please set INSTALL_DIR environment variable."
}

# Construct download URL based on version
get_download_url() {
    local tool="$1"

    if [ "$VERSION" = "latest" ]; then
        echo "https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest/download/$tool"
    elif [ "$VERSION" = "main" ]; then
        echo "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main/bin/$tool"
    else
        echo "https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/$tool"
    fi
}

# Download and install a tool
install_tool() {
    local tool="$1"
    local install_dir="$2"
    local url=$(get_download_url "$tool")
    local temp_file=$(mktemp)

    info "Downloading $tool..."

    if curl -fsSL "$url" -o "$temp_file"; then
        mv "$temp_file" "$install_dir/$tool"
        chmod +x "$install_dir/$tool"
        success "Installed $tool"
        return 0
    else
        rm -f "$temp_file"
        error "Failed to download $tool from $url"
    fi
}

# Check if directory is in PATH
check_path() {
    local dir="$1"
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        warning "$dir is not in your PATH"
        info ""
        info "Add this to your ~/.bashrc or ~/.profile:"
        info "  export PATH=\"$dir:\$PATH\""
        info ""
        return 1
    fi
    return 0
}

# Main installation
main() {
    info "=========================================="
    info "zos-shell-utilities installer"
    info "=========================================="
    info ""

    # Check prerequisites
    check_prerequisites

    # Detect installation directory
    INSTALL_DIR=$(detect_install_dir)
    info "Installation directory: $INSTALL_DIR"
    info "Version: $VERSION"
    info ""

    # Install each tool
    for tool in "${TOOLS[@]}"; do
        install_tool "$tool" "$INSTALL_DIR"
    done

    info ""
    success "=========================================="
    success "Installation complete!"
    success "=========================================="
    info ""
    info "Installed tools:"
    for tool in "${TOOLS[@]}"; do
        info "  - $tool"
    done
    info ""
    info "Location: $INSTALL_DIR"
    info ""

    # Check PATH
    if ! check_path "$INSTALL_DIR"; then
        info "After updating your PATH, you can use the tools:"
    else
        info "You can now use the tools:"
    fi

    for tool in "${TOOLS[@]}"; do
        info "  $tool --help"
    done
    info ""
}

main
