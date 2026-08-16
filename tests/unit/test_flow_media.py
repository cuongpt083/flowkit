"""get_media URL/header fallbacks and Flow-UI video binding."""

from unittest.mock import AsyncMock, patch

import pytest

from agent.services.headers import random_headers
from agent.services.flow_client import (
    FlowClient,
    _bind_intercepted_video_to_request,
    _extract_project_board_clips,
    _extract_user_workflows,
    _workflow_identity_ids,
    _workflow_video_url,
)


def test_extract_workflows_and_video_url():
    mid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    wf = {
        "name": mid,
        "metadata": {"primaryMediaId": mid},
        "media": {
            "name": mid,
            "video": {"fifeUrl": "https://storage.googleapis.com/ai-sandbox-videofx/x.mp4"},
        },
    }
    resp = {"data": {"result": {"data": {"json": {"result": {"userWorkflows": [wf]}}}}}}
    wfs = _extract_user_workflows(resp)
    assert len(wfs) == 1
    assert mid in _workflow_identity_ids(wf)
    assert "videofx" in _workflow_video_url(wf)


def test_get_headers_omit_content_type():
    assert "content-type" not in random_headers(method="GET")
    assert "content-type" in random_headers(method="POST")


@pytest.mark.asyncio
async def test_get_media_tries_plain_url_first():
    client = FlowClient()
    calls = []

    async def fake_send(method, params, timeout=15):
        calls.append(params["url"])
        return {"status": 200, "data": {"video": {"fifeUrl": "https://storage.googleapis.com/v/a.mp4"}}}

    client._send = fake_send
    mid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    result = await client.get_media(mid)
    assert result["status"] == 200
    assert f"/v1/media/{mid}?" in calls[0]
    assert "returnUriOnly=true" in calls[0]


@pytest.mark.asyncio
async def test_bind_intercepted_video_completes_processing_request():
    req = {
        "id": "req-1",
        "type": "GENERATE_VIDEO",
        "status": "PROCESSING",
        "scene_id": "scene-1",
        "orientation": "HORIZONTAL",
        "media_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "request_id": "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
    }
    with patch("agent.db.crud.list_requests", new_callable=AsyncMock) as mock_list, \
         patch("agent.db.crud.update_scene", new_callable=AsyncMock) as mock_scene, \
         patch("agent.db.crud.update_request", new_callable=AsyncMock) as mock_req, \
         patch("agent.services.event_bus.event_bus.emit", new_callable=AsyncMock):
        mock_list.side_effect = [[req], []]
        ok = await _bind_intercepted_video_to_request(
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            "https://flow-content.google/video/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee?x=1",
        )
    assert ok is True
    mock_scene.assert_awaited()
    kwargs = mock_scene.call_args[1]
    assert kwargs["horizontal_video_status"] == "COMPLETED"
    assert kwargs["horizontal_video_media_id"].startswith("aaaaaaaa")
    mock_req.assert_awaited()
    assert mock_req.call_args[1]["status"] == "COMPLETED"


@pytest.mark.asyncio
async def test_sync_falls_back_to_tab_scrape():
    client = FlowClient()
    req = {
        "id": "req-1",
        "type": "GENERATE_VIDEO",
        "status": "PROCESSING",
        "scene_id": "scene-1",
        "orientation": "HORIZONTAL",
        "media_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "request_id": "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
    }
    mid = req["media_id"]
    url = f"https://flow-content.google/video/{mid}?x=1"

    async def fake_send(method, params, timeout=15):
        if method == "scrape_flow_media":
            return {"status": 200, "data": {"href": "https://labs.google/fx/tools/flow", "videoEls": 1, "urls": [url]}}
        return {"status": 400, "data": {"error": {"json": {"message": "Bad Request"}}}}

    client._send = fake_send
    with patch("agent.db.crud.list_requests", new_callable=AsyncMock) as mock_list, \
         patch("agent.db.crud.update_scene", new_callable=AsyncMock), \
         patch("agent.db.crud.update_request", new_callable=AsyncMock), \
         patch("agent.services.event_bus.event_bus.emit", new_callable=AsyncMock):
        mock_list.return_value = [req]
        out = await client.sync_completed_flow_videos()
    assert out["completed"] == 1
    assert out["scraped"] == 1


def test_extract_project_board_clips():
    mid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    wfid = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
    resp = {
        "data": {
            "result": {
                "data": {
                    "json": {
                        "projectContents": {
                            "workflows": [{
                                "name": wfid,
                                "metadata": {"displayName": "Woman speaking passionately abou…", "primaryMediaId": mid},
                            }],
                            "media": [{
                                "name": mid,
                                "workflowId": wfid,
                                "mediaMetadata": {"mediaBlobSize": "1295006"},
                                "video": {"dimensions": {"length": "8s"}, "generatedVideo": {"model": "veo_3_1_i2v_lite_low_priority"}},
                            }],
                        }
                    }
                }
            }
        }
    }
    clips = _extract_project_board_clips(resp)
    assert len(clips) == 1
    assert clips[0]["duration8"] is True
    assert clips[0]["title"].startswith("Woman speaking passionately")
    assert clips[0]["mediaId"] == mid
    assert clips[0]["url"] is None
