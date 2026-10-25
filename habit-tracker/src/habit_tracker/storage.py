"""JSON-file persistence plus the queries the UI needs (streaks, rates, history).

File layout::

    {
      "version": 1,
      "settings": {"appearance": "System"},
      "habits":  [{"id": "...", "name": "Drink water", "kind": "count", ...}],
      "entries": {"2026-10-17": {"<habit id>": 6}}
    }
"""
from __future__ import annotations

import json
import os
import tempfile
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Callable

from .models import Habit

SCHEMA_VERSION = 1
APP_DIR_NAME = "HabitTracker"


def default_data_path() -> Path:
    override = os.environ.get("HABIT_TRACKER_DATA")
    if override:
        return Path(override).expanduser()
    base = os.environ.get("APPDATA") or Path.home() / ".local" / "share"
    return Path(base) / APP_DIR_NAME / "habits.json"


class HabitStore:
    """Holds all habits and daily entries; every mutation is saved immediately."""

    def __init__(self, path: Path | str | None = None) -> None:
        self.path = Path(path) if path else default_data_path()
        self.habits: list[Habit] = []
        self.entries: dict[str, dict[str, float]] = {}
        self.settings: dict = {}
        self.recovered_from: Path | None = None
        self.listeners: list[Callable[[], None]] = []  # called after every save
        self._load()

    # ------------------------------------------------------------------ files
    def _load(self) -> None:
        if not self.path.exists():
            return
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            habits = [Habit.from_dict(h) for h in raw.get("habits", [])]
            entries = {
                day: {hid: float(v) for hid, v in values.items()}
                for day, values in raw.get("entries", {}).items()
            }
            settings = dict(raw.get("settings", {}))
        except (ValueError, TypeError, AttributeError):
            # Keep the unreadable file aside instead of overwriting it.
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            backup = self.path.with_name(f"{self.path.stem}.corrupt-{stamp}{self.path.suffix}")
            self.path.replace(backup)
            self.recovered_from = backup
            return
        self.habits, self.entries, self.settings = habits, entries, settings

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": SCHEMA_VERSION,
            "settings": self.settings,
            "habits": [h.to_dict() for h in self.habits],
            "entries": {day: values for day, values in sorted(self.entries.items()) if values},
        }
        # Write to a temp file first so a crash never leaves a half-written file.
        fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".habits-", suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                json.dump(payload, fh, indent=2, ensure_ascii=False)
            os.replace(tmp, self.path)
        except BaseException:
            Path(tmp).unlink(missing_ok=True)
            raise
        for listener in self.listeners:
            listener()

    # ----------------------------------------------------------------- habits
    def get_habit(self, habit_id: str) -> Habit | None:
        return next((h for h in self.habits if h.id == habit_id), None)

    def add_habit(self, habit: Habit) -> None:
        self.habits.append(habit)
        self.save()

    def update_habit(self, habit: Habit) -> None:
        for i, existing in enumerate(self.habits):
            if existing.id == habit.id:
                self.habits[i] = habit
                self.save()
                return
        raise KeyError(habit.id)

    def delete_habit(self, habit_id: str) -> None:
        self.habits = [h for h in self.habits if h.id != habit_id]
        for values in self.entries.values():
            values.pop(habit_id, None)
        self.entries = {day: values for day, values in self.entries.items() if values}
        self.save()

    def move_habit(self, habit_id: str, offset: int) -> None:
        index = next(i for i, h in enumerate(self.habits) if h.id == habit_id)
        target = index + offset
        if 0 <= target < len(self.habits):
            self.habits[index], self.habits[target] = self.habits[target], self.habits[index]
            self.save()

    def set_setting(self, key: str, value) -> None:
        self.settings[key] = value
        self.save()

    # ---------------------------------------------------------------- entries
    def value(self, habit_id: str, day: date) -> float:
        return self.entries.get(day.isoformat(), {}).get(habit_id, 0.0)

    def set_value(self, habit_id: str, day: date, value: float) -> None:
        key = day.isoformat()
        value = max(0.0, round(float(value), 2))
        if value:
            self.entries.setdefault(key, {})[habit_id] = value
        elif key in self.entries:
            self.entries[key].pop(habit_id, None)
            if not self.entries[key]:
                del self.entries[key]
        self.save()

    def is_done(self, habit: Habit, day: date) -> bool:
        return habit.is_done(self.value(habit.id, day))

    # ---------------------------------------------------------------- queries
    def first_day(self, habit: Habit) -> date:
        """The earlier of the creation date and the first logged entry."""
        days = [date.fromisoformat(d) for d, v in self.entries.items() if habit.id in v]
        return min([date.fromisoformat(habit.created), *days])

    def current_streak(self, habit: Habit, today: date | None = None) -> int:
        """Consecutive done days ending today; an unfinished today doesn't break it."""
        today = today or date.today()
        day = today if self.is_done(habit, today) else today - timedelta(days=1)
        streak = 0
        while self.is_done(habit, day):
            streak += 1
            day -= timedelta(days=1)
        return streak

    def best_streak(self, habit: Habit) -> int:
        done_days = sorted(
            date.fromisoformat(d)
            for d, values in self.entries.items()
            if habit.is_done(values.get(habit.id, 0.0))
        )
        best = run = 0
        previous: date | None = None
        for day in done_days:
            run = run + 1 if previous and (day - previous).days == 1 else 1
            best = max(best, run)
            previous = day
        return best

    def total_done(self, habit: Habit) -> int:
        return sum(habit.is_done(v.get(habit.id, 0.0)) for v in self.entries.values())

    def completion_rate(self, habit: Habit, days: int = 30, today: date | None = None) -> float:
        today = today or date.today()
        start = min(max(today - timedelta(days=days - 1), self.first_day(habit)), today)
        total = (today - start).days + 1
        done = sum(self.is_done(habit, start + timedelta(days=i)) for i in range(total))
        return done / total
