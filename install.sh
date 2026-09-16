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

sync_files() {
    echo "--> Downloading latest dotfiles..."
    mkdir -p "$DOTFILES_DIR"
    curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$DOTFILES_DIR" --strip-components=1

    # Guarantee execution permission on disk after extraction
    [ -f "$DOTFILES_DIR/install.sh" ] && chmod +x "$DOTFILES_DIR/install.sh"

    local possible_dirs=()

    # Detect OS to prioritize native IDE paths
    if [ "$(uname)" = "Darwin" ]; then
        possible_dirs=(
            "$HOME/Library/Application Support/Code/User"
            "$HOME/Library/Application Support/Code - OSS/User"
            "$HOME/Library/Application Support/Antigravity/User"
            "$HOME/Library/Application Support/Cursor/User"
            "$HOME/Library/Application Support/Windsurf/User"
            "$HOME/.config/Code - OSS/User"
            "$HOME/.config/Code/User"
        )
    else
        possible_dirs=(
            "$HOME/.config/Code - OSS/User"
            "$HOME/.config/Code/User"
            "$HOME/.config/VSCodium/User"
            "$HOME/.config/Cursor/User"
            "$HOME/.config/Windsurf/User"
            "$HOME/.config/Antigravity/User"
        )
    fi

    local found_any=0

    for VSCODE_DIR in "${possible_dirs[@]}"; do
        local parent_dir
        parent_dir="$(dirname "$VSCODE_DIR")"

        # Check if the IDE's application folder already exists on the system
        if [ -d "$parent_dir" ] || [ -d "$VSCODE_DIR" ]; then
            found_any=1
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
        fi
    done

    # Fallback if no IDE directories exist yet
    if [ "$found_any" -eq 0 ]; then
        local fallback_dir="$HOME/.config/Code - OSS/User"
        [ "$(uname)" = "Darwin" ] && fallback_dir="$HOME/Library/Application Support/Code/User"

        echo "--> No active IDE folder found. Creating default: $fallback_dir"
        mkdir -p "$fallback_dir/snippets"
        [ -f "$DOTFILES_DIR/settings.json" ] && ln -sf "$DOTFILES_DIR/settings.json" "$fallback_dir/settings.json"
        [ -f "$DOTFILES_DIR/keybindings.json" ] && ln -sf "$DOTFILES_DIR/keybindings.json" "$fallback_dir/keybindings.json"
        if [ -d "$DOTFILES_DIR/snippets" ]; then
            for snippet in "$DOTFILES_DIR/snippets"/*; do
                [ -e "$snippet" ] || continue
                ln -sf "$snippet" "$fallback_dir/snippets/$(basename "$snippet")"
            done
        fi
    fi

    echo "==> Sync complete!"
}

disable_auto() {
    local quiet="$1"
    if [ -f "$SHELL_RC" ]; then
        grep -v "Auto-sync dotfiles" "$SHELL_RC" | grep -v "archive/refs/heads/main.tar.gz" > "${SHELL_RC}.tmp" || true
        mv "${SHELL_RC}.tmp" "$SHELL_RC"
        [ "$quiet" != "quiet" ] && echo "--> Auto-sync disabled in $SHELL_RC"
    fi
}

enable_auto() {
    disable_auto "quiet"
    local sync_cmd="(curl -fsSL $ARCHIVE_URL | tar -xz -C \$HOME/dotfiles --strip-components=1 && chmod +x \$HOME/dotfiles/install.sh) >/dev/null 2>&1 &"
    echo "" >> "$SHELL_RC"
    echo "# Auto-sync dotfiles" >> "$SHELL_RC"
    echo "$sync_cmd" >> "$SHELL_RC"
    echo "--> Auto-sync enabled in $SHELL_RC"
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
