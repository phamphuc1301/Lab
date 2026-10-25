"""System-tray icon: reopen the window or log today's habits straight from the menu."""
from __future__ import annotations

import queue
from datetime import date
from pathlib import Path

import pystray
from PIL import Image

from .models import fmt_number
from .storage import HabitStore


class Tray:
    """Runs pystray on its own thread. Clicks are posted to `events` for the Tk thread."""

    def __init__(self, store: HabitStore, events: queue.Queue, icon_path: Path) -> None:
        self.store, self.events = store, events
        self.day = date.today()
        self.icon = pystray.Icon("HabitTracker", Image.open(icon_path), "Habit Tracker",
                                 menu=pystray.Menu(self._items))

    def _post(self, *event):
        return lambda _icon, _item: self.events.put(event)

    def _items(self):
        yield pystray.MenuItem("Open Habit Tracker", self._post("show"), default=True)
        yield pystray.Menu.SEPARATOR
        today = date.today()
        for habit in self.store.habits:
            value = self.store.value(habit.id, today)
            done = habit.is_done(value)
            if habit.is_numeric:
                text = f"{habit.name}:  {habit.value_text(value)}   (+{fmt_number(habit.step)})"
            else:
                text = habit.name
            yield pystray.MenuItem(text, self._post("log", habit.id), checked=lambda _i, d=done: d)
        if self.store.habits:
            yield pystray.Menu.SEPARATOR
        yield pystray.MenuItem("Quit", self._post("quit"))

    def start(self) -> None:
        self.icon.run_detached()

    def refresh(self) -> None:
        """Rebuild the menu (call from the Tk thread after data changes)."""
        self.day = date.today()
        self.icon.update_menu()

    def notify(self, message: str) -> None:
        try:
            self.icon.notify(message, "Habit Tracker")
        except Exception:  # notifications are best-effort
            pass

    def stop(self) -> None:
        self.icon.stop()
