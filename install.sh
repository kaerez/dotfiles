#!/usr/bin/env bash
set -e

ARCHIVE_URL="https://github.com/kaerez/dotfiles/archive/refs/heads/main.tar.gz"
DOTFILES_DIR="$HOME/dotfiles"
SHELL_RC="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

show_help() {
    echo "Dotfiles Installer & Sync Tool"
    echo ""
    echo "Usage: ~/dotfiles/install.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  (no args)     Run full sync and enable background auto-sync"
    echo "  sync          Perform a one-time manual sync of dotfiles"
    echo "  enable-auto   Enable background auto-sync on terminal launch"
    echo "  disable-auto  Disable background auto-sync"
    echo "  help, -h      Show this help menu"
}

get_target_dirs() {
    local dirs=(
        "$HOME/.config/Code - OSS/User"          # Cloud Shell / Code-OSS (Linux)
        "$HOME/.config/Code/User"                # Standard VS Code (Linux)
        "$HOME/.config/VSCodium/User"            # VSCodium (Linux)
        "$HOME/.config/Cursor/User"              # Cursor (Linux)
        "$HOME/.config/Windsurf/User"            # Windsurf (Linux)
        "$HOME/.config/Antigravity/User"         # Google Antigravity IDE (Linux)
        "$HOME/Library/Application Support/Code/User"        # VS Code (macOS)
        "$HOME/Library/Application Support/Code - OSS/User" # Code-OSS (macOS)
        "$HOME/Library/Application Support/Antigravity/User" # Antigravity (macOS)
        "$HOME/Library/Application Support/Cursor/User"      # Cursor (macOS)
    )
    for d in "${dirs[@]}"; do
        if [ -d "$(dirname "$d")" ] || [ -d "$d" ]; then
            echo "$d"
        fi
    done
}

sync_files() {
    echo "--> Downloading latest dotfiles..."
    mkdir -p "$DOTFILES_DIR"
    curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$DOTFILES_DIR" --strip-components=1

    # Guarantee execution permissions on the local script
    if [ -f "$DOTFILES_DIR/install.sh" ]; then
        chmod +x "$DOTFILES_DIR/install.sh"
    fi

    local targets=($(get_target_dirs))
    [ ${#targets[@]} -eq 0 ] && targets=("$HOME/.config/Code - OSS/User")

    for VSCODE_DIR in "${targets[@]}"; do
        echo "--> Symlinking to: $VSCODE_DIR"
        mkdir -p "$VSCODE_DIR/snippets"

        [ -f "$DOTFILES_DIR/settings.json" ] && ln -sf "$DOTFILES_DIR/settings.json" "$VSCODE_DIR/settings.json"
        [ -f "$DOTFILES_DIR/keybindings.json" ] && ln -sf "$DOTFILES_DIR/keybindings.json" "$VSCODE_DIR/keybindings.json"

        if [ -d "$DOTFILES_DIR/snippets" ]; then
            for snippet in "$DOTFILES_DIR/snippets"/*; do
                [ -e "$snippet" ] || continue
                ln -sf "$snippet" "$VSCODE_DIR/snippets/$(basename "$snippet")"
            done
        fi
    done
    echo "==> Sync complete!"
}

enable_auto() {
    disable_auto
    local sync_cmd="(curl -fsSL $ARCHIVE_URL | tar -xz -C \$HOME/dotfiles --strip-components=1 && chmod +x \$HOME/dotfiles/install.sh) >/dev/null 2>&1 &"
    echo "" >> "$SHELL_RC"
    echo "# Auto-sync dotfiles" >> "$SHELL_RC"
    echo "$sync_cmd" >> "$SHELL_RC"
    echo "--> Auto-sync enabled in $SHELL_RC"
}

disable_auto() {
    if [ -f "$SHELL_RC" ]; then
        grep -v "Auto-sync dotfiles" "$SHELL_RC" | grep -v "archive/refs/heads/main.tar.gz" > "${SHELL_RC}.tmp" || true
        mv "${SHELL_RC}.tmp" "$SHELL_RC"
        echo "--> Auto-sync disabled in $SHELL_RC"
    fi
}

case "$1" in
    sync)
        sync_files
        ;;
    enable-auto)
        enable_auto
        ;;
    disable-auto)
        disable_auto
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        sync_files
        enable_auto
        ;;
esac
