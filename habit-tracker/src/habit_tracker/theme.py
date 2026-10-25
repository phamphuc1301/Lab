"""Colors, fonts and small color helpers. Tuples are (light, dark)."""
from __future__ import annotations

import customtkinter as ctk

FONT_FAMILY = "Segoe UI"

ACCENT = "#6C8CFF"
ACCENT_HOVER = "#5877F2"
ACCENT_SOFT = ("#E9EEFF", "#252D48")
BG = ("#F5F6FA", "#0F1116")
SIDEBAR = ("#FFFFFF", "#15171E")
SURFACE = ("#FFFFFF", "#1A1D25")
SURFACE_ALT = ("#EEF0F6", "#252935")
BORDER = ("#E4E7EF", "#2A2E3A")
TEXT = ("#1A1D26", "#E9EBF1")
MUTED = ("#6E7484", "#8A91A3")
GHOST = ("#C8CDD9", "#3A3F4D")
DANGER = "#E5484D"

PALETTE = [
    "#6C8CFF",  # periwinkle
    "#34C99A",  # mint
    "#FFB547",  # amber
    "#FF6B8B",  # rose
    "#A87CFF",  # lavender
    "#38BDF8",  # sky
    "#F97316",  # tangerine
    "#94A3B8",  # slate
]


def font(size: int = 13, weight: str = "normal") -> ctk.CTkFont:
    return ctk.CTkFont(family=FONT_FAMILY, size=size, weight=weight)


def resolve(color: str | tuple[str, str]) -> str:
    """Pick the light/dark variant for plain tkinter widgets (e.g. Canvas)."""
    if isinstance(color, (tuple, list)):
        return color[1] if ctk.get_appearance_mode() == "Dark" else color[0]
    return color


def mix(color: str, other: str, amount: float) -> str:
    """Blend `amount` of `color` with (1 - amount) of `other`."""
    a = [int(color[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(other[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x * amount + y * (1 - amount)):02X}" for x, y in zip(a, b))
