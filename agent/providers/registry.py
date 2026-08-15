"""Resolve a MediaBackend by project.provider name."""

from __future__ import annotations

import os
from typing import Any

_EXTERNAL = frozenset({"deepinfra"})


def is_external_provider(name: str | None) -> bool:
    return (name or "flow") in _EXTERNAL


def get_media_backend(name: str, flow_client: Any = None):
    """Return a backend instance. `flow` uses the live FlowClient."""
    key = (name or "flow").strip().lower()
    if key in ("", "flow"):
        if flow_client is None:
            from agent.services.flow_client import get_flow_client
            flow_client = get_flow_client()
        from agent.providers.flow import FlowBackend
        return FlowBackend(flow_client)
    if key == "deepinfra":
        from agent.providers.deepinfra import DeepInfraBackend
        return DeepInfraBackend()
    raise ValueError(f"Unknown media provider: {name!r}")


def list_media_backends() -> dict:
    from agent.config import DEEPINFRA_API_KEY
    return {
        "flow": {"configured": True},
        "deepinfra": {"configured": bool(os.environ.get("DEEPINFRA_API_KEY") or DEEPINFRA_API_KEY)},
    }
