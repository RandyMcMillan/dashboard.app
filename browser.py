#!/usr/bin/env python3
import os
import signal
import subprocess
import sys
import venv


def ensure_venv():
    """Run from a local virtual environment that owns PyQt5/PyQtWebEngine."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    venv_dir = os.path.join(script_dir, ".venv-browser")
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
        index_path = os.path.join(script_dir, "Contents", "Resources", "index.html")
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

        # URL Bar
        self.url_bar = QLineEdit()
        self.url_bar.returnPressed.connect(self.navigate_to_url)
        navbar.addWidget(self.url_bar)

        # Update URL bar when page changes
        self.browser.urlChanged.connect(self.update_url)

    def navigate_to_url(self):
        url = self.url_bar.text()
        if not url.startswith('http'):
            url = 'https://' + url
        self.browser.setUrl(QUrl(url))

    def update_url(self, q):
        self.url_bar.setText(q.toString())

app = QApplication(sys.argv)
QApplication.setApplicationName('Python Web Browser')
window = SimpleBrowser()

# Allow clean shutdown with Ctrl+C from the terminal.
signal.signal(signal.SIGINT, lambda signum, frame: app.quit())
timer = QTimer()
timer.start(500)
timer.timeout.connect(lambda: None)

app.exec_()

