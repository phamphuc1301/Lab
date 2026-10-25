"""Domain model: a habit and the way its daily progress is measured."""
from __future__ import annotations

import uuid
from dataclasses import asdict, dataclass, field, fields
from datetime import date

CHECK = "check"
COUNT = "count"
DURATION = "duration"

KIND_LABELS = {CHECK: "Yes / No", COUNT: "Count", DURATION: "Duration"}
KIND_HINTS = {
    CHECK: "Mark it done once a day.",
    COUNT: "Count things, like glasses of water or pages read.",
    DURATION: "Track minutes spent, like 30 min of exercise.",
}


def fmt_number(value: float) -> str:
    value = round(float(value), 2)
    return str(int(value)) if value.is_integer() else f"{value:g}"


@dataclass
class Habit:
    name: str
    kind: str = CHECK
    target: float = 1.0
    unit: str = ""
    step: float = 1.0
    color: str = "#6C8CFF"
    created: str = field(default_factory=lambda: date.today().isoformat())
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:12])

    def __post_init__(self) -> None:
        self.name = str(self.name).strip()
        if not self.name:
            raise ValueError("Please give the habit a name.")
        if self.kind not in KIND_LABELS:
            raise ValueError(f"Unknown measure type: {self.kind!r}")
        if self.kind == CHECK:
            self.target, self.step, self.unit = 1.0, 1.0, ""
            return
        self.target, self.step = float(self.target), float(self.step)
        if self.target <= 0:
            raise ValueError("Daily goal must be greater than zero.")
        if self.step <= 0:
            raise ValueError("Step must be greater than zero.")
        self.unit = "min" if self.kind == DURATION else str(self.unit).strip()

    @property
    def is_numeric(self) -> bool:
        return self.kind != CHECK

    def is_done(self, value: float) -> bool:
        return value >= self.target

    def progress(self, value: float) -> float:
        return max(0.0, min(1.0, value / self.target))

    def goal_text(self) -> str:
        if self.kind == CHECK:
            return "Every day"
        return f"Goal {fmt_number(self.target)} {self.unit}".rstrip()

    def value_text(self, value: float) -> str:
        if self.kind == CHECK:
            return "Done" if self.is_done(value) else "Not yet"
        return f"{fmt_number(value)} / {fmt_number(self.target)} {self.unit}".rstrip()

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Habit":
        known = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in data.items() if k in known})
