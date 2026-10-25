"""The add / edit habit dialog."""
from __future__ import annotations

import tkinter as tk
from typing import Callable

import customtkinter as ctk

from . import theme
from .models import CHECK, COUNT, DURATION, KIND_HINTS, KIND_LABELS, Habit, fmt_number

# (daily goal, step) suggested when switching measure type on a fresh form.
DEFAULTS = {COUNT: ("8", "1"), DURATION: ("30", "5")}
LABEL_TO_KIND = {label: kind for kind, label in KIND_LABELS.items()}


def _parse(text: str, label: str) -> float:
    try:
        return float(text.strip().replace(",", "."))
    except ValueError:
        raise ValueError(f"{label} must be a number.") from None


class HabitDialog(ctk.CTkToplevel):
    def __init__(self, master, habit: Habit | None, on_save: Callable[[Habit], None],
                 default_color: str = theme.ACCENT) -> None:
        super().__init__(master, fg_color=theme.BG)
        self.habit, self.on_save = habit, on_save
        self.kind = habit.kind if habit else CHECK
        self.color = habit.color if habit else default_color
        self.count_unit = habit.unit if habit and habit.kind == COUNT else ""

        self.title("Edit habit" if habit else "New habit")
        self.resizable(False, False)
        self.transient(master)

        body = ctk.CTkFrame(self, fg_color="transparent")
        body.pack(fill="both", expand=True, padx=26, pady=22)
        ctk.CTkLabel(body, text=self.title(), font=theme.font(20, "bold"),
                     text_color=theme.TEXT).pack(anchor="w", pady=(0, 10))

        self._label(body, "Name")
        self.name_entry = self._entry(body, "e.g. Drink water, Read, Meditate", width=380)
        self.name_entry.pack(fill="x")

        self._label(body, "How do you measure it?")
        self.kind_seg = ctk.CTkSegmentedButton(
            body, values=list(KIND_LABELS.values()), command=self._on_kind_label, height=36,
            font=theme.font(13), corner_radius=10, fg_color=theme.SURFACE_ALT,
            selected_color=theme.SURFACE, selected_hover_color=theme.SURFACE,
            unselected_color=theme.SURFACE_ALT, unselected_hover_color=theme.BORDER,
            text_color=theme.TEXT)
        self.kind_seg.pack(fill="x")
        self.hint = ctk.CTkLabel(body, text="", font=theme.font(12), text_color=theme.MUTED, anchor="w")
        self.hint.pack(fill="x", pady=(4, 0))

        self.numeric = ctk.CTkFrame(body, fg_color="transparent")
        self.numeric.grid_columnconfigure((0, 1, 2), weight=1, uniform="n")
        self.target_entry = self._entry(self.numeric, "8")
        self.unit_entry = self._entry(self.numeric, "glasses")
        self.step_entry = self._entry(self.numeric, "1")
        for col, (text, entry) in enumerate((("Daily goal", self.target_entry),
                                             ("Unit", self.unit_entry),
                                             ("+/− step", self.step_entry))):
            pad = (0 if col == 0 else 6, 0 if col == 2 else 6)
            ctk.CTkLabel(self.numeric, text=text, font=theme.font(12, "bold"), text_color=theme.MUTED,
                         anchor="w").grid(row=0, column=col, sticky="w", padx=pad, pady=(12, 4))
            entry.configure(width=110)
            entry.grid(row=1, column=col, sticky="ew", padx=pad)

        self.color_label = self._label(body, "Color")
        swatches = ctk.CTkFrame(body, fg_color="transparent")
        swatches.pack(anchor="w")
        self.swatches: dict[str, ctk.CTkButton] = {}
        for color in theme.PALETTE:
            btn = ctk.CTkButton(swatches, text="", width=30, height=30, corner_radius=15,
                                fg_color=color, hover_color=theme.mix(color, "#000000", 0.85),
                                border_color=theme.TEXT, command=lambda c=color: self._pick_color(c))
            btn.pack(side="left", padx=(0, 8))
            self.swatches[color] = btn

        self.error = ctk.CTkLabel(body, text="", font=theme.font(12), text_color=theme.DANGER, anchor="w")
        self.error.pack(fill="x", pady=(10, 0))

        buttons = ctk.CTkFrame(body, fg_color="transparent")
        buttons.pack(fill="x", pady=(6, 0))
        ctk.CTkButton(buttons, text="Save" if habit else "Create habit", height=38, corner_radius=10,
                      fg_color=theme.ACCENT, hover_color=theme.ACCENT_HOVER, font=theme.font(14, "bold"),
                      command=self._save).pack(side="right")
        ctk.CTkButton(buttons, text="Cancel", height=38, width=90, corner_radius=10,
                      fg_color="transparent", hover_color=theme.SURFACE_ALT, border_width=1,
                      border_color=theme.BORDER, text_color=theme.TEXT, font=theme.font(14),
                      command=self.destroy).pack(side="right", padx=(0, 8))

        self._prefill()
        self.bind("<Return>", lambda _e: self._save())
        self.bind("<Escape>", lambda _e: self.destroy())
        self.after(10, self._center)
        self.after(150, self._activate)

    # ------------------------------------------------------------- helpers
    def _label(self, master, text: str) -> ctk.CTkLabel:
        label = ctk.CTkLabel(master, text=text, font=theme.font(12, "bold"),
                             text_color=theme.MUTED, anchor="w")
        label.pack(fill="x", pady=(14, 4))
        return label

    def _entry(self, master, placeholder: str, width: int = 140) -> ctk.CTkEntry:
        return ctk.CTkEntry(master, placeholder_text=placeholder, height=38, width=width, corner_radius=10,
                            border_width=1, border_color=theme.BORDER, fg_color=theme.SURFACE,
                            text_color=theme.TEXT, font=theme.font(14))

    @staticmethod
    def _set_text(entry: ctk.CTkEntry, text: str) -> None:
        state = entry.cget("state")
        entry.configure(state="normal")
        entry.delete(0, tk.END)
        if text:
            entry.insert(0, text)
        entry.configure(state=state)

    def _prefill(self) -> None:
        habit = self.habit
        if habit:
            self._set_text(self.name_entry, habit.name)
            if habit.is_numeric:
                self._set_text(self.target_entry, fmt_number(habit.target))
                self._set_text(self.step_entry, fmt_number(habit.step))
        self.kind_seg.set(KIND_LABELS[self.kind])
        self._on_kind(self.kind)
        self._pick_color(self.color)

    def _center(self) -> None:
        self.update_idletasks()
        master = self.master
        x = master.winfo_rootx() + (master.winfo_width() - self.winfo_width()) // 2
        y = master.winfo_rooty() + (master.winfo_height() - self.winfo_height()) // 3
        self.wm_geometry(f"+{max(x, 0)}+{max(y, 0)}")  # bypasses CTk's size scaling

    def _activate(self) -> None:
        self.lift()
        self.focus_force()
        self.name_entry.focus()
        try:
            self.grab_set()
        except tk.TclError:
            pass

    # ------------------------------------------------------------- events
    def _on_kind_label(self, label: str) -> None:
        self._on_kind(LABEL_TO_KIND[label])

    def _on_kind(self, kind: str) -> None:
        if self.kind == COUNT and self.unit_entry.cget("state") == "normal":
            self.count_unit = self.unit_entry.get()
        self.kind = kind
        self.hint.configure(text=KIND_HINTS[kind])
        if kind == CHECK:
            self.numeric.pack_forget()
            return
        self.numeric.pack(fill="x", before=self.color_label)
        # Swap in sensible numbers unless the user typed their own.
        suggested = {v for pair in DEFAULTS.values() for v in pair} | {""}
        goal, step = DEFAULTS[kind]
        if self.target_entry.get() in suggested and self.step_entry.get() in suggested:
            self._set_text(self.target_entry, goal)
            self._set_text(self.step_entry, step)
        if kind == DURATION:
            self.unit_entry.configure(state="normal")
            self._set_text(self.unit_entry, "min")
            self.unit_entry.configure(state="disabled", text_color=theme.MUTED)
        else:
            self.unit_entry.configure(state="normal", text_color=theme.TEXT)
            self._set_text(self.unit_entry, self.count_unit)

    def _pick_color(self, color: str) -> None:
        self.color = color
        for c, btn in self.swatches.items():
            btn.configure(border_width=3 if c == color else 0)

    def _save(self) -> None:
        try:
            numeric = self.kind != CHECK
            fields = dict(
                name=self.name_entry.get(),
                kind=self.kind,
                target=_parse(self.target_entry.get(), "Daily goal") if numeric else 1,
                step=_parse(self.step_entry.get() or "1", "Step") if numeric else 1,
                unit=self.unit_entry.get() if numeric else "",
                color=self.color,
            )
            habit = Habit(**{**self.habit.to_dict(), **fields}) if self.habit else Habit(**fields)
        except ValueError as exc:
            self.error.configure(text=str(exc))
            return
        self.grab_release()
        self.destroy()
        self.on_save(habit)
