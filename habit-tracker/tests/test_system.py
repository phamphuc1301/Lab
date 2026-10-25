import sys
import threading

import pytest

from habit_tracker import system

pytestmark = pytest.mark.skipif(sys.platform != "win32", reason="Windows only")


def test_second_launch_reaches_first_instance(tmp_path):
    first = system.SingleInstance(str(tmp_path))
    assert not first.notify_existing()  # nothing running yet

    received = threading.Event()
    messages = []
    first.listen(lambda m: (messages.append(m), received.set()))
    try:
        assert system.SingleInstance(str(tmp_path)).notify_existing("show")
        assert received.wait(5)
        assert messages == ["show"]
    finally:
        first.close()


def test_launch_command_starts_in_background():
    assert system.launch_command().endswith(system.BACKGROUND_FLAG)
