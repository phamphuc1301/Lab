"""Main window: sidebar navigation plus the Today and Overview screens."""
from __future__ import annotations

import os
import queue
import sys
import traceback
from datetime import date, timedelta
from pathlib import Path
from tkinter import messagebox

import customtkinter as ctk

from . import __version__, system, theme
from .dialogs import HabitDialog
from .models import Habit
from .storage import HabitStore
from .widgets import HabitCard, Heatmap

try:
    from .tray import Tray
except ImportError:  # pystray/Pillow missing: run without a tray icon
    Tray = None

ICON_PATH = Path(__file__).parent / "assets" / "icon.ico"
APPEARANCES = ["Light", "Dark", "System"]


def _empty_state(master, title: str, text: str, button: str | None, command=None) -> ctk.CTkFrame:
    frame = ctk.CTkFrame(master, fg_color=theme.SURFACE, corner_radius=16,
                         border_width=1, border_color=theme.BORDER)
    ctk.CTkLabel(frame, text="◎", font=theme.font(40), text_color=theme.ACCENT).pack(pady=(36, 4))
    ctk.CTkLabel(frame, text=title, font=theme.font(18, "bold"), text_color=theme.TEXT).pack()
    ctk.CTkLabel(frame, text=text, font=theme.font(13), text_color=theme.MUTED,
                 justify="center").pack(pady=(6, 18 if button else 36))
    if button:
        ctk.CTkButton(frame, text=button, height=38, corner_radius=10, fg_color=theme.ACCENT,
                      hover_color=theme.ACCENT_HOVER, font=theme.font(14, "bold"),
                      command=command).pack(pady=(0, 36))
    return frame


class Header(ctk.CTkFrame):
    def __init__(self, master) -> None:
        super().__init__(master, fg_color="transparent")
        self.grid_columnconfigure(0, weight=1)
        self.title = ctk.CTkLabel(self, text="", font=theme.font(28, "bold"), text_color=theme.TEXT, anchor="w")
        self.title.grid(row=0, column=0, sticky="w")
        self.subtitle = ctk.CTkLabel(self, text="", font=theme.font(14), text_color=theme.MUTED, anchor="w")
        self.subtitle.grid(row=1, column=0, sticky="w")
        self.actions = ctk.CTkFrame(self, width=1, height=1, fg_color="transparent")
        self.actions.grid(row=0, column=1, rowspan=2, sticky="e")


class TodayView(ctk.CTkFrame):
    def __init__(self, master, app: "App") -> None:
        super().__init__(master, fg_color="transparent")
        self.app, self.store = app, app.store
        self.day = date.today()
        self.cards: list[HabitCard] = []
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)

        self.header = Header(self)
        self.header.grid(row=0, column=0, sticky="ew", padx=36, pady=(30, 16))
        nav_style = dict(height=34, corner_radius=10, fg_color=theme.SURFACE, hover_color=theme.SURFACE_ALT,
                         border_width=1, border_color=theme.BORDER, text_color=theme.TEXT,
                         text_color_disabled=theme.GHOST, font=theme.font(14))
        self.prev_btn = ctk.CTkButton(self.header.actions, text="‹", width=34,
                                      command=lambda: self.shift(-1), **nav_style)
        self.today_btn = ctk.CTkButton(self.header.actions, text="Today", width=70,
                                       command=lambda: self.set_day(date.today()), **nav_style)
        self.next_btn = ctk.CTkButton(self.header.actions, text="›", width=34,
                                      command=lambda: self.shift(1), **nav_style)
        for btn in (self.prev_btn, self.today_btn, self.next_btn):
            btn.pack(side="left", padx=3)

        summary = ctk.CTkFrame(self, fg_color=theme.SURFACE, corner_radius=14,
                               border_width=1, border_color=theme.BORDER)
        summary.grid(row=1, column=0, sticky="ew", padx=36, pady=(0, 10))
        summary.grid_columnconfigure(0, weight=1)
        self.summary_label = ctk.CTkLabel(summary, text="", font=theme.font(14, "bold"),
                                          text_color=theme.TEXT, anchor="w")
        self.summary_label.grid(row=0, column=0, sticky="w", padx=18, pady=(14, 6))
        self.percent_label = ctk.CTkLabel(summary, text="", font=theme.font(14, "bold"), text_color=theme.ACCENT)
        self.percent_label.grid(row=0, column=1, sticky="e", padx=18, pady=(14, 6))
        self.summary_bar = ctk.CTkProgressBar(summary, height=8, corner_radius=4,
                                              progress_color=theme.ACCENT, fg_color=theme.SURFACE_ALT)
        self.summary_bar.grid(row=1, column=0, columnspan=2, sticky="ew", padx=18, pady=(0, 16))

        self.list = ctk.CTkScrollableFrame(self, fg_color="transparent",
                                           scrollbar_button_color=theme.BORDER,
                                           scrollbar_button_hover_color=theme.GHOST)
        self.list.grid(row=2, column=0, sticky="nsew", padx=(26, 16), pady=(0, 20))

    def shift(self, days: int) -> None:
        self.set_day(self.day + timedelta(days=days))

    def set_day(self, day: date) -> None:
        self.day = min(day, date.today())
        self.render()

    def render(self) -> None:
        today = date.today()
        self.day = min(self.day, today)
        delta = (today - self.day).days
        self.header.title.configure(text={0: "Today", 1: "Yesterday"}.get(delta, f"{self.day:%A}"))
        self.header.subtitle.configure(text=f"{self.day:%A}, {self.day.day} {self.day:%B %Y}")
        self.next_btn.configure(state="disabled" if delta == 0 else "normal")
        self.today_btn.configure(state="disabled" if delta == 0 else "normal")

        for child in self.list.winfo_children():
            child.destroy()
        self.cards = []
        if not self.store.habits:
            _empty_state(self.list, "No habits yet",
                         "Start small: add one habit you want to do every day.\n"
                         "You can measure it as done / not done, a count, or minutes.",
                         "+  Create your first habit", self.app.new_habit).pack(fill="x", padx=10, pady=6)
        for habit in self.store.habits:
            card = HabitCard(self.list, self.store, habit, self.day, on_change=self.update_summary,
                             on_edit=self.app.edit_habit, on_delete=self.app.delete_habit,
                             on_move=self.app.move_habit)
            card.pack(fill="x", padx=(10, 6), pady=6)
            self.cards.append(card)
        self.update_summary()

    def update_summary(self) -> None:
        habits = self.store.habits
        done = sum(self.store.is_done(h, self.day) for h in habits)
        total = len(habits)
        ratio = done / total if total else 0
        if total and done == total:
            text = "All done. Great job!"
        else:
            text = f"{done} of {total} habit{'s' if total != 1 else ''} completed"
        self.summary_label.configure(text=text)
        self.percent_label.configure(text=f"{ratio:.0%}")
        self.summary_bar.set(ratio)


class OverviewCard(ctk.CTkFrame):
    def __init__(self, master, store: HabitStore, habit: Habit) -> None:
        super().__init__(master, fg_color=theme.SURFACE, corner_radius=14,
                         border_width=1, border_color=theme.BORDER)
        head = ctk.CTkFrame(self, fg_color="transparent")
        head.pack(fill="x", padx=20, pady=(16, 10))
        ctk.CTkFrame(head, width=12, height=12, corner_radius=6, fg_color=habit.color).pack(side="left", padx=(0, 10))
        ctk.CTkLabel(head, text=habit.name, font=theme.font(16, "bold"), text_color=theme.TEXT).pack(side="left")
        ctk.CTkLabel(head, text=habit.goal_text(), font=theme.font(12),
                     text_color=theme.MUTED).pack(side="right")

        stats = ctk.CTkFrame(self, fg_color="transparent")
        stats.pack(fill="x", padx=20)
        stats.grid_columnconfigure((0, 1, 2, 3), weight=1, uniform="s")
        current, best = store.current_streak(habit), store.best_streak(habit)
        items = [
            ("Current streak", f"{current} day{'s' if current != 1 else ''}"),
            ("Best streak", f"{best} day{'s' if best != 1 else ''}"),
            ("Last 30 days", f"{store.completion_rate(habit):.0%}"),
            ("Total completed", str(store.total_done(habit))),
        ]
        for col, (label, value) in enumerate(items):
            box = ctk.CTkFrame(stats, fg_color=theme.SURFACE_ALT, corner_radius=10)
            box.grid(row=0, column=col, sticky="ew", padx=(0 if col == 0 else 5, 0 if col == 3 else 5))
            ctk.CTkLabel(box, text=value, font=theme.font(18, "bold"),
                         text_color=theme.TEXT).pack(anchor="w", padx=12, pady=(8, 0))
            ctk.CTkLabel(box, text=label, font=theme.font(11),
                         text_color=theme.MUTED).pack(anchor="w", padx=12, pady=(0, 8))

        Heatmap(self, store, habit).pack(anchor="w", padx=20, pady=(14, 18))


class OverviewView(ctk.CTkFrame):
    def __init__(self, master, app: "App") -> None:
        super().__init__(master, fg_color="transparent")
        self.app, self.store = app, app.store
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        self.header = Header(self)
        self.header.grid(row=0, column=0, sticky="ew", padx=36, pady=(30, 16))
        self.header.title.configure(text="Overview")
        self.header.subtitle.configure(text="Streaks and history over the last six months")
        self.list = ctk.CTkScrollableFrame(self, fg_color="transparent",
                                           scrollbar_button_color=theme.BORDER,
                                           scrollbar_button_hover_color=theme.GHOST)
        self.list.grid(row=1, column=0, sticky="nsew", padx=(26, 16), pady=(0, 20))

    def render(self) -> None:
        for child in self.list.winfo_children():
            child.destroy()
        if not self.store.habits:
            _empty_state(self.list, "Nothing to show yet",
                         "Your streaks and history appear here once you add habits.",
                         "+  New habit", self.app.new_habit).pack(fill="x", padx=10, pady=6)
        for habit in self.store.habits:
            OverviewCard(self.list, self.store, habit).pack(fill="x", padx=(10, 6), pady=6)


class App(ctk.CTk):
    def __init__(self, store: HabitStore, start_hidden: bool = False) -> None:
        super().__init__(fg_color=theme.BG)
        self.store = store
        # Messages from other threads (tray clicks, second launches) land here.
        self.events: queue.Queue = queue.Queue()
        self.tray = Tray(store, self.events, ICON_PATH) if Tray and ICON_PATH.exists() else None
        self.title("Habit Tracker")
        self.geometry("1000x720")
        self.minsize(860, 580)
        if ICON_PATH.exists():
            self.iconbitmap(str(ICON_PATH))
        self.grid_columnconfigure(2, weight=1)
        self.grid_rowconfigure(0, weight=1)

        self._build_sidebar()
        ctk.CTkFrame(self, width=1, corner_radius=0, fg_color=theme.BORDER).grid(row=0, column=1, sticky="ns")
        self.views = {"today": TodayView(self, self), "overview": OverviewView(self, self)}
        self.current = ""
        self.show("today")

        self.bind("<Left>", lambda _e: self.current == "today" and self.views["today"].shift(-1))
        self.bind("<Right>", lambda _e: self.current == "today" and self.views["today"].shift(1))
        self.bind("<Control-n>", lambda _e: self.new_habit())
        self.bind("<FocusIn>", self._check_new_day)
        self.protocol("WM_DELETE_WINDOW", self.close_window)

        if self.tray:
            store.listeners.append(self.tray.refresh)
            self.tray.start()
            if start_hidden:
                self.withdraw()
        self.after(200, self._poll_events)
        if store.recovered_from:
            self.after(400, lambda: messagebox.showwarning(
                "Data file could not be read",
                f"Your data file was unreadable and has been kept as:\n{store.recovered_from}\n\n"
                "Habit Tracker started with an empty list.", parent=self))

    # -------------------------------------------------------------- layout
    def _build_sidebar(self) -> None:
        side = ctk.CTkFrame(self, width=232, corner_radius=0, fg_color=theme.SIDEBAR)
        side.grid(row=0, column=0, sticky="ns")
        side.pack_propagate(False)

        brand = ctk.CTkFrame(side, fg_color="transparent")
        brand.pack(fill="x", padx=20, pady=(28, 26))
        ctk.CTkLabel(brand, text="✓", width=38, height=38, corner_radius=11, fg_color=theme.ACCENT,
                     text_color="#FFFFFF", font=theme.font(18, "bold")).pack(side="left")
        names = ctk.CTkFrame(brand, fg_color="transparent")
        names.pack(side="left", padx=(12, 0))
        ctk.CTkLabel(names, text="Habit Tracker", font=theme.font(16, "bold"), text_color=theme.TEXT,
                     height=20, anchor="w").pack(anchor="w")
        ctk.CTkLabel(names, text="Small steps, every day", font=theme.font(11), text_color=theme.MUTED,
                     height=16, anchor="w").pack(anchor="w")

        self.nav: dict[str, ctk.CTkButton] = {}
        for key, label in (("today", "◉   Today"), ("overview", "▦   Overview")):
            btn = ctk.CTkButton(side, text=label, anchor="w", height=40, corner_radius=10,
                                fg_color="transparent", hover_color=theme.SURFACE_ALT,
                                text_color=theme.TEXT, font=theme.font(14),
                                command=lambda k=key: self.show(k))
            btn.pack(fill="x", padx=14, pady=2)
            self.nav[key] = btn

        ctk.CTkButton(side, text="+   New habit", height=42, corner_radius=10, fg_color=theme.ACCENT,
                      hover_color=theme.ACCENT_HOVER, font=theme.font(14, "bold"),
                      command=self.new_habit).pack(fill="x", padx=14, pady=(18, 0))

        bottom = ctk.CTkFrame(side, fg_color="transparent")
        bottom.pack(side="bottom", fill="x", padx=14, pady=18)
        switch_style = dict(font=theme.font(13), text_color=theme.TEXT, progress_color=theme.ACCENT,
                            fg_color=theme.GHOST, button_color="#FFFFFF",
                            button_hover_color="#F1F3F8", switch_width=36, switch_height=18)
        self.autostart_switch = ctk.CTkSwitch(bottom, text="Start with Windows",
                                              command=self._toggle_autostart, **switch_style)
        self.autostart_switch.pack(fill="x", padx=4, pady=(0, 8))
        if system.autostart_enabled():
            self.autostart_switch.select()
        self.background_switch = ctk.CTkSwitch(bottom, text="Keep running in tray",
                                               command=self._toggle_background, **switch_style)
        self.background_switch.pack(fill="x", padx=4, pady=(0, 16))
        if self.run_in_background:
            self.background_switch.select()
        if not self.tray:
            self.background_switch.configure(state="disabled")
        ctk.CTkLabel(bottom, text="Appearance", font=theme.font(12, "bold"), text_color=theme.MUTED,
                     anchor="w").pack(fill="x", padx=4, pady=(0, 6))
        self.appearance = ctk.CTkSegmentedButton(
            bottom, values=APPEARANCES, command=self.set_appearance, height=32, font=theme.font(12),
            corner_radius=9, fg_color=theme.SURFACE_ALT, selected_color=theme.SURFACE,
            selected_hover_color=theme.SURFACE, unselected_color=theme.SURFACE_ALT,
            unselected_hover_color=theme.BORDER, text_color=theme.TEXT)
        self.appearance.set(self.store.settings.get("appearance", "System"))
        self.appearance.pack(fill="x")
        ctk.CTkButton(bottom, text="Open data folder", height=30, anchor="w", corner_radius=8,
                      fg_color="transparent", hover_color=theme.SURFACE_ALT, text_color=theme.MUTED,
                      font=theme.font(12), command=self.open_data_folder).pack(fill="x", pady=(14, 0))
        ctk.CTkLabel(bottom, text=f"Version {__version__}", font=theme.font(11), text_color=theme.GHOST,
                     anchor="w").pack(fill="x", padx=4)

    def show(self, key: str) -> None:
        if self.current:
            self.views[self.current].grid_forget()
        self.current = key
        view = self.views[key]
        view.render()
        view.grid(row=0, column=2, sticky="nsew")
        for k, btn in self.nav.items():
            active = k == key
            btn.configure(fg_color=theme.ACCENT_SOFT if active else "transparent",
                          text_color=theme.ACCENT if active else theme.TEXT,
                          font=theme.font(14, "bold" if active else "normal"))

    def render_current(self) -> None:
        self.views[self.current].render()

    # ------------------------------------------------------------- actions
    def new_habit(self) -> None:
        color = theme.PALETTE[len(self.store.habits) % len(theme.PALETTE)]
        HabitDialog(self, None, self._created, default_color=color)

    def _created(self, habit: Habit) -> None:
        self.store.add_habit(habit)
        self.render_current()

    def edit_habit(self, habit: Habit) -> None:
        HabitDialog(self, habit, self._edited)

    def _edited(self, habit: Habit) -> None:
        self.store.update_habit(habit)
        self.render_current()

    def delete_habit(self, habit: Habit) -> None:
        if messagebox.askyesno("Delete habit",
                               f"Delete “{habit.name}” and all of its history?\nThis cannot be undone.",
                               icon="warning", parent=self):
            self.store.delete_habit(habit.id)
            self.render_current()

    def move_habit(self, habit: Habit, offset: int) -> None:
        self.store.move_habit(habit.id, offset)
        self.render_current()

    def set_appearance(self, mode: str) -> None:
        ctk.set_appearance_mode(mode)
        self.store.set_setting("appearance", mode)
        self.render_current()  # redraw plain-tk canvases with the new colors

    def open_data_folder(self) -> None:
        self.store.path.parent.mkdir(parents=True, exist_ok=True)
        os.startfile(self.store.path.parent)  # noqa: S606 - Windows only

    # ------------------------------------------------------ tray & window
    @property
    def run_in_background(self) -> bool:
        return bool(self.tray) and self.store.settings.get("run_in_background", True)

    def _toggle_autostart(self) -> None:
        system.set_autostart(bool(self.autostart_switch.get()))

    def _toggle_background(self) -> None:
        self.store.set_setting("run_in_background", bool(self.background_switch.get()))

    def close_window(self) -> None:
        if not self.run_in_background:
            self.quit_app()
            return
        self.withdraw()
        if not self.store.settings.get("tray_hint_shown"):
            self.tray.notify("Still running in the tray. Click the icon to log your habits.")
            self.store.set_setting("tray_hint_shown", True)

    def show_window(self) -> None:
        self.deiconify()
        if self.state() == "iconic":
            self.state("normal")
        self.lift()
        self.attributes("-topmost", True)  # Windows won't always raise a window otherwise
        self.after(150, lambda: self.attributes("-topmost", False))
        self.focus_force()
        self._check_new_day()

    def quit_app(self) -> None:
        if self.tray:
            self.tray.stop()
        self.destroy()

    def _poll_events(self) -> None:
        try:
            while True:
                event = self.events.get_nowait()
                if event[0] == "show":
                    self.show_window()
                elif event[0] == "quit":
                    self.quit_app()
                    return
                elif event[0] == "log":
                    self._log_from_tray(event[1])
        except queue.Empty:
            pass
        if self.tray and self.tray.day != date.today():
            self.tray.refresh()  # new day: reset the menu's checkmarks
        self.after(200, self._poll_events)

    def _log_from_tray(self, habit_id: str) -> None:
        habit = self.store.get_habit(habit_id)
        if habit is None:
            return
        today = date.today()
        value = self.store.value(habit.id, today)
        if habit.is_numeric:
            self.store.set_value(habit.id, today, value + habit.step)
        else:
            self.store.set_value(habit.id, today, 0 if habit.is_done(value) else 1)
        self.render_current()

    def _check_new_day(self, _event=None) -> None:
        # If the app stayed open past midnight, roll "Today" forward.
        today_view = self.views["today"]
        if self.current == "today" and getattr(self, "_last_seen", None) not in (None, date.today()):
            today_view.set_day(date.today())
        self._last_seen = date.today()

    def report_callback_exception(self, exc, val, tb) -> None:
        if sys.stderr:
            traceback.print_exception(exc, val, tb)
        messagebox.showerror("Something went wrong", f"{exc.__name__}: {val}", parent=self)


def _set_windows_app_id() -> None:
    """Give the process its own taskbar identity so our icon is used."""
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("Lab.HabitTracker")
        except (AttributeError, OSError):
            pass


def main() -> None:
    store = HabitStore()
    instance = system.SingleInstance(str(store.path))
    if instance.notify_existing("show"):
        return  # already running: the existing window comes to the front
    _set_windows_app_id()
    _mutex = system.hold_app_mutex()  # noqa: F841 - held for the process lifetime
    if system.autostart_enabled():
        system.set_autostart(True)  # keep the sign-in command pointing at this install

    ctk.set_appearance_mode(store.settings.get("appearance", "System"))
    ctk.set_default_color_theme("blue")
    app = App(store, start_hidden=system.BACKGROUND_FLAG in sys.argv[1:])
    instance.listen(lambda message: app.events.put((message,)))
    try:
        app.mainloop()
    finally:
        instance.close()
