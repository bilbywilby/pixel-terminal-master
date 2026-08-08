#!/usr/bin/env python3
import os
import subprocess
import sys

def clear_clipboard():
    cleared = False
    
    # Wayland support
    if os.environ.get("WAYLAND_DISPLAY") or os.environ.get("XDG_SESSION_TYPE") == "wayland":
        try:
            subprocess.run(["wl-copy", "--clear"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["wl-copy", "--primary", "--clear"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("✓ Cleared Wayland clipboard (clipboard & primary)")
            cleared = True
        except (FileNotFoundError, subprocess.CalledProcessError):
            pass

    # X11 support
    if os.environ.get("DISPLAY") or not cleared:
        try:
            for sel in ["clipboard", "primary", "secondary"]:
                subprocess.run(["xclip", "-selection", sel, "/dev/null"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("✓ Cleared X11 clipboard (clipboard, primary & secondary)")
            cleared = True
        except (FileNotFoundError, subprocess.CalledProcessError):
            pass

    if not cleared:
        print("⚠ No active display server clipboard detected", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    clear_clipboard()
