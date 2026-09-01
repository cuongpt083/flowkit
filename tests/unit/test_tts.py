"""Tests for OmniVoice TTS interpreter resolution."""
import sys
from unittest.mock import patch

from agent.services.tts import get_tts_python_bin


def test_tts_python_bin_env_override(monkeypatch):
    monkeypatch.setenv("TTS_PYTHON_BIN", r"C:\venvs\omnivoice\python.exe")
    assert get_tts_python_bin() == r"C:\venvs\omnivoice\python.exe"


def test_tts_python_bin_windows_defaults_to_sys_executable(monkeypatch):
    monkeypatch.delenv("TTS_PYTHON_BIN", raising=False)
    with patch("agent.services.tts.os.name", "nt"):
        assert get_tts_python_bin() == sys.executable


def test_tts_python_bin_posix_defaults_to_python310(monkeypatch):
    monkeypatch.delenv("TTS_PYTHON_BIN", raising=False)
    with patch("agent.services.tts.os.name", "posix"):
        assert get_tts_python_bin() == "python3.10"
