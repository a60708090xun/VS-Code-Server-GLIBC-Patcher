#!/bin/bash
#
# Automatically patch the VS Code Server to use a custom GLIBC toolchain
# Version 3.5: Support multiple binaries + --force + --list + --restore + --status + --clean + --help

set -e

# --- Configure your paths here ---
TOOLCHAIN_SYSROOT_DIR="/opt/toolchain-vscode-ssh/x86_64-linux-gnu/x86_64-linux-gnu/sysroot"
PATCHELF_PATH="/usr/local/bin/patchelf"
# ---------------------------------

# --- Derived variables ---
GLIBC_LINKER="${TOOLCHAIN_SYSROOT_DIR}/lib/ld-linux-x86-64.so.2"
GLIBC_PATH="${TOOLCHAIN_SYSROOT_DIR}/lib"
# -------------------------------------------------------------

VSCODE_DIR="$HOME/.vscode-server"

# --- Usage function ---
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --force     Re-patch all VS Code Server binaries (even if already patched).
  --list      Only list detected VS Code Server binaries, do not patch.
  --restore   Restore all binaries from their *.original backups.
  --status    Show patching status of all binaries.
  --clean     Remove wrapper + .original, keep only the original binary.
  --help      Show this help message.

Examples:
  $(basename "$0")             # Patch all unpatched binaries
  $(basename "$0") --force     # Force re-patch all binaries
  $(basename "$0") --list      # List binaries without patching
  $(basename "$0") --restore   # Restore all binaries to original
  $(basename "$0") --status    # Show patch/restore status
  $(basename "$0") --clean     # Delete wrappers & .original, leave only original
EOF
}

# --- Parse arguments ---
FORCE=false
LIST_ONLY=false
RESTORE=false
STATUS=false
CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --force)   FORCE=true ;;
        --list)    LIST_ONLY=true ;;
        --restore) RESTORE=true ;;
        --status)  STATUS=true ;;
        --clean)   CLEAN=true ;;
        --help)    usage; exit 0 ;;
        *) echo "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

echo "Searching for VS Code Server directory: $VSCODE_DIR"
if [ ! -d "$VSCODE_DIR" ]; then
    echo "Error: VS Code Server directory not found at $VSCODE_DIR."
    echo "Please try to connect with VS Code Remote-SSH at least once to download the server files."
    exit 1
fi

# Find all target executables (filename format is 'code-<commit-hash>')
TARGET_FILES=$(find "$VSCODE_DIR" -name 'code-*' -type f -executable ! -name '*.original')

# --- Handle --status ---
if [ "$STATUS" = true ]; then
    echo "VS Code Server binaries status:"
    for FILE in $TARGET_FILES; do
        ORIGINAL_FILE="${FILE}.original"
        if [ -f "$ORIGINAL_FILE" ]; then
            if head -n 1 "$FILE" | grep -q "#!/bin/bash"; then
                STATUS_STR="PATCHED"
            else
                STATUS_STR="UNKNOWN"
            fi
        else
            STATUS_STR="ORIGINAL"
        fi
        echo " - $FILE : $STATUS_STR"
    done
    exit 0
fi

# --- Handle --restore ---
if [ "$RESTORE" = true ]; then
    echo "Restoring all patched binaries..."
    RESTORED=false
    for ORIGINAL_FILE in $(find "$VSCODE_DIR" -name 'code-*.original' -type f); do
        TARGET_FILE="${ORIGINAL_FILE%.original}"
        mv -f "$ORIGINAL_FILE" "$TARGET_FILE"
        chmod +x "$TARGET_FILE"
        echo "Restored: $TARGET_FILE"
        RESTORED=true
    done
    if [ "$RESTORED" = false ]; then
        echo "No .original files found. Nothing to restore."
    else
        echo "Restore complete!"
    fi
    exit 0
fi

# --- Handle --clean ---
if [ "$CLEAN" = true ]; then
    echo "Cleaning patched binaries (remove wrapper + .original)..."
    CLEANED=false
    for WRAPPER in $TARGET_FILES; do
        ORIGINAL_FILE="${WRAPPER}.original"
        if [ -f "$ORIGINAL_FILE" ]; then
            rm -f "$WRAPPER"
            mv "$ORIGINAL_FILE" "$WRAPPER"
            chmod +x "$WRAPPER"
            echo "Cleaned: $WRAPPER (restored original, removed wrapper)"
            CLEANED=true
        fi
    done
    if [ "$CLEANED" = false ]; then
        echo "No patched binaries found. Nothing to clean."
    else
        echo "Clean complete!"
    fi
    exit 0
fi

# --- Handle --list ---
if [ -z "$TARGET_FILES" ]; then
    echo "No VS Code Server binaries found in $VSCODE_DIR."
    exit 0
fi

if [ "$LIST_ONLY" = true ]; then
    echo "Detected VS Code Server binaries:"
    echo "$TARGET_FILES"
    exit 0
fi

# --- Default: patch process ---
for TARGET_FILE in $TARGET_FILES; do
    echo "-------------------------------------------------------------"
    echo "Found target server file: $TARGET_FILE"

    ORIGINAL_FILE="${TARGET_FILE}.original"

    if [ -f "$ORIGINAL_FILE" ] && [ "$FORCE" = false ]; then
        echo "Already patched: $TARGET_FILE (use --force to re-patch)"
        continue
    fi

    echo "Patching: $TARGET_FILE"

    if [ -f "$ORIGINAL_FILE" ] && [ "$FORCE" = true ]; then
        mv -f "$ORIGINAL_FILE" "$TARGET_FILE"
        echo "Restored original binary for: $TARGET_FILE"
    fi

    mv "$TARGET_FILE" "$ORIGINAL_FILE"
    echo "Original file backed up to: $ORIGINAL_FILE"

    cat <<EOF > "$TARGET_FILE"
#!/bin/bash
#
# VS Code Server Wrapper Script (auto-generated by auto_patch_vscode.sh)

export VSCODE_SERVER_CUSTOM_GLIBC_LINKER="$GLIBC_LINKER"
export VSCODE_SERVER_CUSTOM_GLIBC_PATH="$GLIBC_PATH"
export VSCODE_SERVER_PATCHELF_PATH="$PATCHELF_PATH"

exec "$ORIGINAL_FILE" "\$@"
EOF

    chmod +x "$TARGET_FILE"
    echo "Successfully created wrapper script: $TARGET_FILE"
done

echo "-------------------------------------------------------------"
echo "Patching complete! All VS Code Server binaries processed."
