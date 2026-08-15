"""Unit tests for DeepInfra media backend — mocked HTTP, no network."""

from __future__ import annotations

import pytest

from agent.providers.deepinfra import DeepInfraBackend


class _FakeResp:
    def __init__(self, status, payload):
        self.status = status
        self._payload = payload

    async def json(self, content_type=None):
        return self._payload

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False


class _FakeSession:
    def __init__(self, handler):
        self.handler = handler
        self.calls = []

    def request(self, method, url, headers=None, json=None):
        self.calls.append({"method": method, "url": url, "json": json})
        status, payload = self.handler(method, url, json)
        return _FakeResp(status, payload)


@pytest.mark.asyncio
async def test_generate_images_returns_flow_shaped_envelope():
    session = _FakeSession(lambda m, u, j: (200, {
        "data": [{"url": "https://cdn.example/img.png"}],
    }))
    backend = DeepInfraBackend(api_key="k", session=session)
    result = await backend.generate_images("a cat", "proj", "IMAGE_ASPECT_RATIO_PORTRAIT")
    assert result["data"]["media"][0]["image"]["generatedImage"]["fifeUrl"] == "https://cdn.example/img.png"
    assert session.calls[0]["method"] == "POST"
    assert "/images/generations" in session.calls[0]["url"]


@pytest.mark.asyncio
async def test_generate_video_pending_does_not_look_complete():
    session = _FakeSession(lambda m, u, j: (200, {"id": "job-1", "status": "queued"}))
    backend = DeepInfraBackend(api_key="k", session=session)
    result = await backend.generate_video("https://cdn.example/start.png", "walk", "proj")
    assert result["data"]["operations"][0]["operation"]["name"] == "job-1"
    assert result["data"]["operations"][0]["status"] == "MEDIA_GENERATION_STATUS_PENDING"


@pytest.mark.asyncio
async def test_check_status_then_complete():
    def handler(method, url, body):
        assert method == "GET"
        return 200, {"id": "job-1", "status": "completed", "url": "https://cdn.example/v.mp4"}

    session = _FakeSession(handler)
    backend = DeepInfraBackend(api_key="k", session=session)
    result = await backend.check_video_status([
        {"operation": {"name": "job-1"}, "status": "MEDIA_GENERATION_STATUS_PENDING"}
    ])
    assert result["data"]["operations"][0]["status"] == "MEDIA_GENERATION_STATUS_SUCCESSFUL"
    assert result["data"]["operations"][0]["operation"]["metadata"]["video"]["fifeUrl"].endswith(".mp4")


@pytest.mark.asyncio
async def test_missing_key():
    backend = DeepInfraBackend(api_key="")
    result = await backend.generate_images("x", "p")
    assert "DEEPINFRA_API_KEY" in result["error"]


@pytest.mark.asyncio
async def test_unsupported_ops():
    backend = DeepInfraBackend(api_key="k")
    assert "UNSUPPORTED_ON_PROVIDER" in (await backend.upscale_video("m")).get("error", "")
    assert "UNSUPPORTED_ON_PROVIDER" in (await backend.generate_video_from_references([])).get("error", "")
