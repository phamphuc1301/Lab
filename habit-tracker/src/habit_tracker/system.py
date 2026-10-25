"""Windows integration: start with Windows, and a single running instance."""
from __future__ import annotations

import hashlib
import os
import sys
import threading
from multiprocessing.connection import AuthenticationError, Client, Listener
from pathlib import Path
from typing import Callable

RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
RUN_VALUE = "HabitTracker"
BACKGROUND_FLAG = "--background"
MUTEX_NAME = "Lab.HabitTracker"  # also referenced by AppMutex in packaging/installer.iss
_AUTHKEY = b"habit-tracker"


# ---------------------------------------------------------------- autostart
def launch_command() -> str:
    """The command Windows runs at sign-in: start hidden in the tray."""
    if getattr(sys, "frozen", False):
        return f'"{sys.executable}" {BACKGROUND_FLAG}'
    pythonw = Path(sys.executable).with_name("pythonw.exe")
    exe = pythonw if pythonw.exists() else Path(sys.executable)
    return f'"{exe}" -m habit_tracker {BACKGROUND_FLAG}'


def autostart_enabled() -> bool:
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
            winreg.QueryValueEx(key, RUN_VALUE)
        return True
    except (ImportError, OSError):
        return False


def set_autostart(enabled: bool) -> None:
    import winreg
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as key:
        if enabled:
            winreg.SetValueEx(key, RUN_VALUE, 0, winreg.REG_SZ, launch_command())
        else:
            try:
                winreg.DeleteValue(key, RUN_VALUE)
            except FileNotFoundError:
                pass


def hold_app_mutex():
    """Named mutex so the installer/uninstaller can tell the app is running."""
    if sys.platform != "win32":
        return None
    import ctypes
    return ctypes.windll.kernel32.CreateMutexW(None, False, MUTEX_NAME)


# ----------------------------------------------------------- single instance
class SingleInstance:
    """The first instance listens on a named pipe; later launches ask it to show itself."""

    def __init__(self, key: str) -> None:
        user = os.environ.get("USERNAME", "user")
        digest = hashlib.sha1(f"{user}|{key}".encode()).hexdigest()[:12]
        self.address = rf"\\.\pipe\HabitTracker-{digest}"
        self._listener: Listener | None = None

    def notify_existing(self, message: str = "show") -> bool:
        """Send `message` to a running instance. False if none is running."""
        try:
            with Client(self.address, family="AF_PIPE", authkey=_AUTHKEY) as conn:
                conn.send(message)
            return True
        except (OSError, EOFError, AuthenticationError):
            return False

    def listen(self, on_message: Callable[[str], None]) -> None:
        """Serve messages on a background thread; `on_message` runs on that thread."""
        try:
            self._listener = Listener(self.address, family="AF_PIPE", authkey=_AUTHKEY)
        except OSError:
            return  # lost a launch race; run without it
        threading.Thread(target=self._serve, args=(on_message,), daemon=True).start()

    def _serve(self, on_message: Callable[[str], None]) -> None:
        while self._listener is not None:
            try:
                with self._listener.accept() as conn:
                    on_message(conn.recv())
            except (OSError, EOFError, AuthenticationError):
                continue

    def close(self) -> None:
        listener, self._listener = self._listener, None
        if listener is not None:
            listener.close()
