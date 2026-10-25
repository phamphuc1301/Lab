"""Reusable UI pieces: the daily habit card, week dots and the history heatmap."""
from __future__ import annotations

import tkinter as tk
from datetime import date, timedelta
from tkinter import messagebox
from typing import Callable

import customtkinter as ctk

from . import theme
from .models import Habit, fmt_number
from .storage import HabitStore


class WeekDots(ctk.CTkFrame):
    """Seven small dots showing which of the last 7 days were completed."""

    def __init__(self, master, color: str) -> None:
        super().__init__(master, fg_color="transparent")
        self.color = color
        self.dots = []
        for _ in range(7):
            dot = ctk.CTkFrame(self, width=9, height=9, corner_radius=5, fg_color=theme.GHOST)
            dot.pack(side="left", padx=2)
            self.dots.append(dot)

    def show(self, done: list[bool]) -> None:
        for dot, is_done in zip(self.dots, done):
            dot.configure(fg_color=self.color if is_done else theme.GHOST)


class HabitCard(ctk.CTkFrame):
    """One habit on the Today screen with a control that fits its measure type."""

    def __init__(
        self,
        master,
        store: HabitStore,
        habit: Habit,
        day: date,
        on_change: Callable[[], None],
        on_edit: Callable[[Habit], None],
        on_delete: Callable[[Habit], None],
        on_move: Callable[[Habit, int], None],
    ) -> None:
        super().__init__(master, fg_color=theme.SURFACE, corner_radius=14,
                         border_width=1, border_color=theme.BORDER)
        self.store, self.habit, self.day = store, habit, day
        self.on_change, self.on_edit, self.on_delete, self.on_move = on_change, on_edit, on_delete, on_move
        self.grid_columnconfigure(1, weight=1)

        ctk.CTkFrame(self, width=5, height=1, corner_radius=3, fg_color=habit.color).grid(
            row=0, column=0, rowspan=3, sticky="ns", padx=(14, 14), pady=16)

        ctk.CTkLabel(self, text=habit.name, font=theme.font(15, "bold"),
                     text_color=theme.TEXT, anchor="w").grid(row=0, column=1, sticky="sw", pady=(14, 0))

        meta = ctk.CTkFrame(self, fg_color="transparent")
        meta.grid(row=1, column=1, sticky="nw", pady=(0, 6 if habit.is_numeric else 14))
        self.meta_label = ctk.CTkLabel(meta, text="", font=theme.font(12), text_color=theme.MUTED)
        self.meta_label.pack(side="left")
        self.dots = WeekDots(meta, habit.color)
        self.dots.pack(side="left", padx=(12, 0))

        controls = ctk.CTkFrame(self, fg_color="transparent")
        controls.grid(row=0, column=2, rowspan=2, padx=(8, 0), pady=(12, 0 if habit.is_numeric else 12))
        if habit.is_numeric:
            step_style = dict(width=34, height=34, corner_radius=17, fg_color=theme.SURFACE_ALT,
                              hover_color=theme.BORDER, text_color=theme.TEXT, font=theme.font(18))
            self.minus = ctk.CTkButton(controls, text="−", command=lambda: self._bump(-1), **step_style)
            self.value_btn = ctk.CTkButton(controls, text="", width=120, height=34, corner_radius=10,
                                           fg_color="transparent", hover_color=theme.SURFACE_ALT,
                                           font=theme.font(14, "bold"), command=self._enter_value)
            self.plus = ctk.CTkButton(controls, text="+", command=lambda: self._bump(1), **step_style)
            self.minus.pack(side="left")
            self.value_btn.pack(side="left", padx=4)
            self.plus.pack(side="left")
            self.bar = ctk.CTkProgressBar(self, height=6, corner_radius=3,
                                          progress_color=habit.color, fg_color=theme.SURFACE_ALT)
            self.bar.grid(row=2, column=1, columnspan=2, sticky="ew", padx=(0, 4), pady=(0, 16))
        else:
            self.check_btn = ctk.CTkButton(controls, text="✓", width=42, height=42, corner_radius=21,
                                           border_width=2, border_color=habit.color,
                                           font=theme.font(18, "bold"), command=self._toggle)
            self.check_btn.pack()

        self.menu_btn = ctk.CTkButton(self, text="⋯", width=32, height=32, corner_radius=10,
                                      fg_color="transparent", hover_color=theme.SURFACE_ALT,
                                      text_color=theme.MUTED, font=theme.font(16), command=self._open_menu)
        self.menu_btn.grid(row=0, column=3, rowspan=2, padx=(4, 10))
        self.refresh()

    def refresh(self) -> None:
        habit, day = self.habit, self.day
        value = self.store.value(habit.id, day)
        done = habit.is_done(value)
        streak = self.store.current_streak(habit, day)
        parts = [habit.goal_text()]
        if streak:
            parts.append(f"{streak}-day streak")
        self.meta_label.configure(text="  ·  ".join(parts))
        self.dots.show([self.store.is_done(habit, day - timedelta(days=i)) for i in range(6, -1, -1)])

        if habit.is_numeric:
            self.value_btn.configure(text=habit.value_text(value),
                                     text_color=habit.color if done else theme.TEXT)
            self.bar.set(habit.progress(value))
            self.minus.configure(state="normal" if value > 0 else "disabled")
        elif done:
            self.check_btn.configure(fg_color=habit.color, text_color="#FFFFFF",
                                     hover_color=theme.mix(habit.color, "#000000", 0.85))
        else:
            self.check_btn.configure(fg_color="transparent", text_color=theme.GHOST,
                                     hover_color=theme.SURFACE_ALT)

    # --------------------------------------------------------------- actions
    def _set(self, value: float) -> None:
        self.store.set_value(self.habit.id, self.day, value)
        self.refresh()
        self.on_change()

    def _toggle(self) -> None:
        self._set(0 if self.store.is_done(self.habit, self.day) else 1)

    def _bump(self, direction: int) -> None:
        self._set(max(0.0, self.store.value(self.habit.id, self.day) + direction * self.habit.step))

    def _enter_value(self) -> None:
        unit = f" ({self.habit.unit})" if self.habit.unit else ""
        current = fmt_number(self.store.value(self.habit.id, self.day))
        dialog = ctk.CTkInputDialog(title=self.habit.name,
                                    text=f"Value for {self.day:%a %d %b}{unit}\nCurrently {current}")
        raw = dialog.get_input()
        if raw is None or not raw.strip():
            return
        try:
            value = float(raw.strip().replace(",", "."))
        except ValueError:
            messagebox.showerror("Invalid value", f"“{raw}” is not a number.", parent=self)
            return
        self._set(value)

    def _open_menu(self) -> None:
        menu = tk.Menu(self, tearoff=0, font=(theme.FONT_FAMILY, 10))
        menu.add_command(label="Edit…", command=lambda: self.on_edit(self.habit))
        menu.add_command(label="Move up", command=lambda: self.on_move(self.habit, -1))
        menu.add_command(label="Move down", command=lambda: self.on_move(self.habit, 1))
        if self.habit.is_numeric:
            menu.add_command(label="Reset this day", command=lambda: self._set(0))
        menu.add_separator()
        menu.add_command(label="Delete…", command=lambda: self.on_delete(self.habit))
        x = self.menu_btn.winfo_rootx()
        y = self.menu_btn.winfo_rooty() + self.menu_btn.winfo_height()
        try:
            menu.tk_popup(x, y)
        finally:
            menu.grab_release()


class Heatmap(tk.Canvas):
    """GitHub-style grid: one column per week, one row per weekday."""

    CELL, GAP, LEFT, TOP = 12, 3, 30, 18

    def __init__(self, master, store: HabitStore, habit: Habit, weeks: int = 26) -> None:
        self.store, self.habit, self.weeks = store, habit, weeks
        # Plain tk widgets aren't DPI-scaled by customtkinter, so scale manually.
        self.s = ctk.ScalingTracker.get_widget_scaling(master)
        pitch = self.CELL + self.GAP
        super().__init__(master, highlightthickness=0, bd=0,
                         width=self._px(self.LEFT + weeks * pitch),
                         height=self._px(self.TOP + 7 * pitch))
        self.draw()

    def _px(self, value: float) -> int:
        return round(value * self.s)

    def draw(self) -> None:
        self.delete("all")
        surface, empty, muted = (theme.resolve(c) for c in (theme.SURFACE, theme.SURFACE_ALT, theme.MUTED))
        self.configure(bg=surface)
        label_font = (theme.FONT_FAMILY, -self._px(10))
        pitch = self.CELL + self.GAP
        habit, today = self.habit, date.today()
        start = today - timedelta(days=today.weekday(), weeks=self.weeks - 1)  # a Monday

        for text, row in (("Mon", 0), ("Wed", 2), ("Fri", 4)):
            self.create_text(0, self._px(self.TOP + row * pitch + self.CELL / 2),
                             text=text, anchor="w", fill=muted, font=label_font)

        # Label the columns where a month starts; label column 0 only if there's room.
        month_cols = [c for c in range(1, self.weeks)
                      if (start + timedelta(weeks=c)).month != (start + timedelta(weeks=c - 1)).month]
        if not month_cols or month_cols[0] >= 3:
            month_cols.insert(0, 0)
        for col in month_cols:
            self.create_text(self._px(self.LEFT + col * pitch), 0, anchor="nw", fill=muted, font=label_font,
                             text=f"{start + timedelta(weeks=col):%b}")

        for col in range(self.weeks):
            week_start = start + timedelta(weeks=col)
            x = self.LEFT + col * pitch
            for row in range(7):
                day = week_start + timedelta(days=row)
                if day > today:
                    continue
                progress = habit.progress(self.store.value(habit.id, day))
                if progress >= 1:
                    fill = habit.color
                elif progress > 0:
                    fill = theme.mix(habit.color, empty, 0.3 + 0.4 * progress)
                else:
                    fill = empty
                y = self.TOP + row * pitch
                self.create_rectangle(self._px(x), self._px(y), self._px(x + self.CELL),
                                      self._px(y + self.CELL), fill=fill, outline="")
