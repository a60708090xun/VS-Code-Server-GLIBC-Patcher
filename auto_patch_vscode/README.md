# VS Code Server GLIBC Patcher

## Purpose

This script provides a workaround for running modern versions of VS Code Server on older Linux distributions that have an outdated GLIBC (e.g., GLIBC \< 2.28). It works by using `patchelf` and a custom-built GLIBC toolchain to patch the server executable on the fly.

The script automates the "Swap Method," where the original VS Code Server executable is replaced by a wrapper script. This wrapper sets the necessary environment variables before launching the original server, allowing it to run successfully.

## Prerequisites

Before using this script, you must have the following available on the remote host:

1.  A custom GLIBC toolchain (version \>= 2.28).
2.  The `patchelf` binary installed and available in your `PATH` or at a known location.

#### ref. to vscode faq: https://code.visualstudio.com/docs/remote/faq#_can-i-run-vs-code-server-on-older-linux-distributions
1.  Build the sysroot
2.  VS Code server uses patchelf during the installation process to consume the required libraries from the sysroot
   * Install the patchelf binary and the sysroot on the remote host (https://github.com/NixOS/patchelf)
   * Create the following 3 environment variables:
     - VSCODE_SERVER_CUSTOM_GLIBC_LINKER path to the dynamic linker in the sysroot (used for --set-interpreter option with patchelf)
     - VSCODE_SERVER_CUSTOM_GLIBC_PATH path to the library locations in the sysroot (used as --set-rpath option with patchelf)
     - VSCODE_SERVER_PATCHELF_PATH path to the patchelf binary on the remote host

## How to Use

1.  **Configure the Script:** Open the `auto_patch_vscode.sh` script and edit the three variables in the "Configure your paths here" section to match your environment.

2.  **Upload the Script:** Place the `auto_patch_vscode.sh` file in the home directory of your user on the remote host (e.g., `~/auto_patch_vscode.sh`).

3.  **Make it Executable:** Log into your remote host via a standard SSH terminal and run the following command:

    ```bash
    chmod +x ~/auto_patch_vscode.sh
    ```

## When to Run This Script

The workflow is now very simple:

#### First-Time Setup

1.  Attempt to connect with VS Code once. The connection will fail, but this is necessary to download the server files.
2.  On the remote host, run the script: `./auto_patch_vscode.sh`.
3.  Done\! VS Code should now be able to connect successfully.

#### After a VS Code Update

1.  When you update your local VS Code, the first connection attempt will download a **new server executable** (`code-<new-hash>`) to the remote host. The connection will fail again due to the GLIBC issue.
2.  You just need to log into the remote host and **run `./auto_patch_vscode.sh` again**.
3.  The script will automatically find the new executable and perform the swap operation for it.
4.  The issue is resolved, and VS Code can connect again.

This automation script simplifies a complex manual process into a single "fix-it" command that you can run whenever needed.
