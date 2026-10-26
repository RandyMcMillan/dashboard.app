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

        script_dir = os.path.dirname(os.path.abspath(__file__))
        index_path = os.path.join(script_dir, "index.html")
        self.browser.setUrl(QUrl.fromLocalFile(index_path))
        self.setCentralWidget(self.browser)
        self.showMaximized()

        # Navigation Bar
        navbar = QToolBar()
        self.addToolBar(navbar)

        # Back Button
        back_btn = QAction('← Back', self)
        back_btn.triggered.connect(self.browser.back)
        navbar.addAction(back_btn)

        # Forward Button
        forward_btn = QAction('Forward →', self)
        forward_btn.triggered.connect(self.browser.forward)
        navbar.addAction(forward_btn)

        # Reload Button
        reload_btn = QAction('Reload ↻', self)
        reload_btn.triggered.connect(self.browser.reload)
        navbar.addAction(reload_btn)

    def closeEvent(self, event):
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

