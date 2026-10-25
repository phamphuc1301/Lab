import json
from datetime import date, timedelta

import pytest

from habit_tracker.models import CHECK, COUNT, DURATION, Habit
from habit_tracker.storage import HabitStore

TODAY = date(2026, 10, 17)


@pytest.fixture
def store(tmp_path):
    return HabitStore(tmp_path / "habits.json")


def days_ago(n: int) -> date:
    return TODAY - timedelta(days=n)


def test_habit_validation():
    with pytest.raises(ValueError):
        Habit(name="   ")
    with pytest.raises(ValueError):
        Habit(name="Water", kind=COUNT, target=0)
    check = Habit(name="Stretch", kind=CHECK, target=5, unit="x")
    assert (check.target, check.unit) == (1.0, "")
    assert Habit(name="Run", kind=DURATION, target=30, unit="hours").unit == "min"


def test_roundtrip_and_delete(store, tmp_path):
    water = Habit(name="Water", kind=COUNT, target=8, unit="glasses")
    read = Habit(name="Read")
    store.add_habit(water)
    store.add_habit(read)
    store.set_value(water.id, TODAY, 3)
    store.set_value(read.id, TODAY, 1)

    reloaded = HabitStore(tmp_path / "habits.json")
    assert [h.name for h in reloaded.habits] == ["Water", "Read"]
    assert reloaded.value(water.id, TODAY) == 3

    reloaded.delete_habit(water.id)
    again = HabitStore(tmp_path / "habits.json")
    assert [h.id for h in again.habits] == [read.id]
    assert water.id not in json.dumps(json.loads((tmp_path / "habits.json").read_text())["entries"])


def test_zero_value_removes_entry(store):
    habit = Habit(name="Read")
    store.add_habit(habit)
    store.set_value(habit.id, TODAY, 1)
    store.set_value(habit.id, TODAY, 0)
    assert store.entries == {}


def test_streaks(store):
    habit = Habit(name="Read", created=days_ago(10).isoformat())
    store.add_habit(habit)
    for n in (1, 2, 3, 6, 7, 8, 9):
        store.set_value(habit.id, days_ago(n), 1)
    # Today not done yet: the streak through yesterday still counts.
    assert store.current_streak(habit, TODAY) == 3
    store.set_value(habit.id, TODAY, 1)
    assert store.current_streak(habit, TODAY) == 4
    assert store.best_streak(habit) == 4


def test_numeric_progress_counts_only_when_goal_met(store):
    habit = Habit(name="Water", kind=COUNT, target=8, created=days_ago(1).isoformat())
    store.add_habit(habit)
    store.set_value(habit.id, days_ago(1), 8)
    store.set_value(habit.id, TODAY, 5)
    assert not store.is_done(habit, TODAY)
    assert store.completion_rate(habit, days=30, today=TODAY) == 0.5
    assert habit.progress(5) == 5 / 8


def test_move_habit(store):
    a, b = Habit(name="A"), Habit(name="B")
    store.add_habit(a)
    store.add_habit(b)
    store.move_habit(b.id, -1)
    assert [h.name for h in store.habits] == ["B", "A"]
    store.move_habit(b.id, -1)  # already first: no-op
    assert [h.name for h in store.habits] == ["B", "A"]


def test_corrupt_file_is_backed_up(tmp_path):
    path = tmp_path / "habits.json"
    path.write_text("{ not json", encoding="utf-8")
    store = HabitStore(path)
    assert store.habits == []
    assert store.recovered_from and store.recovered_from.exists()
    assert not path.exists()


def test_listeners_called_on_save(store):
    calls = []
    store.listeners.append(lambda: calls.append(1))
    store.add_habit(Habit(name="Read"))
    assert calls == [1]
