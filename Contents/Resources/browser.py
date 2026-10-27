#!/usr/bin/env python3
import ctypes
import os
import signal
import subprocess
import sys
import venv


def venv_directory():
    """Return a venv location outside the app bundle so signing is not affected."""
    support_dir = os.path.expanduser("~/Library/Application Support/dashboard.app")
    os.makedirs(support_dir, exist_ok=True)
    return os.path.join(support_dir, ".venv-browser")


def ensure_venv():
    """Run from a local virtual environment that owns PyQt5/PyQtWebEngine."""
    venv_dir = venv_directory()
    venv_python = os.path.join(venv_dir, "bin", "python")

    # If we are already inside the target venv, just try the imports.
    if sys.executable == venv_python:
        return

    # Create the venv if it does not exist.
    if not os.path.exists(venv_python):
        print("Creating virtual environment in", venv_dir)
        venv.create(venv_dir, with_pip=True)

    # Make sure the dependencies are installed in the venv.
    required = ["PyQt5", "PyQtWebEngine"]
    print("Installing dependencies into virtual environment...")
    subprocess.check_call(
        [venv_python, "-m", "pip", "install", "--upgrade"] + required
    )

    # Restart this script using the venv interpreter.
    print("Restarting with virtual environment interpreter...")
    os.execv(venv_python, [venv_python] + sys.argv)


ensure_venv()

import os as _os
import socket as _socket
import subprocess as _subprocess
import time as _time

_script_dir = _os.path.dirname(_os.path.abspath(__file__))
_ipfs_bin = _os.path.normpath(_os.path.join(_script_dir, "..", "MacOS", "ipfs"))
_support_dir = _os.path.expanduser("~/Library/Application Support/dashboard.app")
_repo_dir = _os.path.join(_support_dir, "ipfsrepo")
_os.makedirs(_support_dir, exist_ok=True)
_os.makedirs(_repo_dir, exist_ok=True)


def _port_in_use(port):
    try:
        with _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM) as s:
            s.settimeout(0.5)
            return s.connect_ex(("127.0.0.1", port)) == 0
    except Exception:
        return False


daemon_proc = None
webui_url = None
if _os.path.exists(_ipfs_bin):
    try:
        if not _os.path.exists(_os.path.join(_repo_dir, "config")):
            _subprocess.run(
                [_ipfs_bin, "init"],
                env={**_os.environ, "IPFS_PATH": _repo_dir},
                check=True,
                stdout=_subprocess.DEVNULL,
                stderr=_subprocess.DEVNULL,
            )
        if not _port_in_use(5001):
            daemon_proc = _subprocess.Popen(
                [_ipfs_bin, "daemon"],
                env={**_os.environ, "IPFS_PATH": _repo_dir},
                stdout=_subprocess.DEVNULL,
                stderr=_subprocess.DEVNULL,
            )
            for _ in range(100):
                if _port_in_use(5001):
                    break
                _time.sleep(0.2)
        if _port_in_use(5001):
            webui_url = "http://127.0.0.1:5001/webui"
    except Exception as exc:
        print("IPFS startup failed:", exc)

from PyQt5.QtCore import *
from PyQt5.QtWidgets import *
from PyQt5.QtWebEngineWidgets import *

class SimpleBrowser(QMainWindow):
    def __init__(self):
        super().__init__()
        self.browser = QWebEngineView()

        # Use an off-the-record profile so multiple runs do not fight over the
        # same on-disk cookie/SQLite database.
        profile = QWebEngineProfile(self.browser)
        page = QWebEnginePage(profile, self.browser)
        self.browser.setPage(page)

        global webui_url
        if webui_url:
            self.browser.setUrl(QUrl(webui_url))
        else:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            index_path = os.path.join(script_dir, "index.html")
            self.browser.loadFinished.connect(self.disable_page_scroll)
            self.browser.setUrl(QUrl.fromLocalFile(index_path))
        self.setCentralWidget(self.browser)

        self.resize(1200, 800)
        self.show()

    def disable_page_scroll(self):
        """Lock the page so swiping up/down does not scroll it."""
        if getattr(self, '_scroll_disabled', False):
            return
        self._scroll_disabled = True

        js = """
        (function() {
            if (document.getElementById('dashboard-no-scroll')) return;
            var style = document.createElement('style');
            style.id = 'dashboard-no-scroll';
            style.textContent = 'html, body { overflow: hidden !important; height: 100% !important; width: 100% !important; }';
            document.head.appendChild(style);
        })();
        """
        self.browser.page().runJavaScript(js)

    def closeEvent(self, event):
        global daemon_proc
        if daemon_proc is not None:
            daemon_proc.terminate()
            try:
                daemon_proc.wait(timeout=10)
            except Exception:
                daemon_proc.kill()
        QApplication.quit()
        event.accept()


def hide_dock_icon():
    """Run without a Dock icon on macOS."""
    try:
        appkit = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/AppKit.framework/AppKit")
        objc = ctypes.cdll.LoadLibrary("/usr/lib/libobjc.dylib")

        objc.objc_getClass.restype = ctypes.c_void_p
        objc.sel_registerName.restype = ctypes.c_void_p
        objc.objc_msgSend.restype = ctypes.c_void_p
        objc.objc_msgSend.argtypes = [ctypes.c_void_p, ctypes.c_void_p]

        ns_app_class = objc.objc_getClass(b"NSApplication")
        shared_app_sel = objc.sel_registerName(b"sharedApplication")
        ns_app = objc.objc_msgSend(ns_app_class, shared_app_sel)

        # NSApplicationActivationPolicyAccessory = 1 (no Dock icon, windows allowed)
        set_policy_sel = objc.sel_registerName(b"setActivationPolicy:")
        objc.objc_msgSend.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long]
        objc.objc_msgSend(ns_app, set_policy_sel, 1)
    except Exception:
        pass


app = QApplication(sys.argv)
app.setQuitOnLastWindowClosed(True)
QApplication.setApplicationName('Python Web Browser')

# Hide the Dock icon after QApplication owns the shared NSApplication instance.
hide_dock_icon()

window = SimpleBrowser()

# Allow clean shutdown with Ctrl+C from the terminal.
signal.signal(signal.SIGINT, lambda signum, frame: app.quit())
timer = QTimer()
timer.start(500)
timer.timeout.connect(lambda: None)

app.exec_()

