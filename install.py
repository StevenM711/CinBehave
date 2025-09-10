diff --git a//dev/null b/install.py
index 0000000000000000000000000000000000000000..828c6871dbf2a976e6d08731c789fb5dffbf2be3 100644
--- a//dev/null
+++ b/install.py
@@ -0,0 +1,42 @@
+#!/usr/bin/env python3
+"""Simple cross-platform installer launcher for CinBehave.
+
+This script detects the operating system and executes the corresponding
+installation script so that users can simply double-click this file after
+downloading the project. The existing platform-specific scripts remain
+responsible for performing the actual setup steps.
+"""
+import os
+import platform
+import subprocess
+import sys
+
+
+def main() -> None:
+    """Run the appropriate installer for the current platform."""
+    repo_root = os.path.dirname(os.path.abspath(__file__))
+    system = platform.system()
+
+    try:
+        if system == "Windows":
+            script = os.path.join(repo_root, "install_windows.bat")
+            if not os.path.exists(script):
+                print("Missing 'install_windows.bat' in repository root.")
+                sys.exit(1)
+            # Execute the batch file through cmd
+            subprocess.run(["cmd", "/c", script], check=True)
+        else:
+            script = os.path.join(repo_root, "install.sh")
+            if not os.path.exists(script):
+                print("Missing 'install.sh' in repository root.")
+                sys.exit(1)
+            # Use bash to execute shell script
+            subprocess.run(["bash", script], check=True)
+    except subprocess.CalledProcessError as exc:
+        # Propagate the exit code from the installer script
+        print(f"Installer failed with exit code {exc.returncode}.")
+        sys.exit(exc.returncode)
+
+
+if __name__ == "__main__":
+    main()
