"""DeepInfra HTTP backend (OpenAI-compatible images + videos)."""

from __future__ import annotations

import logging
from typing import Any
from urllib.parse import urljoin

import aiohttp

from agent.config import (
    DEEPINFRA_API_KEY,
    DEEPINFRA_BASE_URL,
    DEEPINFRA_IMAGE_MODEL,
    DEEPINFRA_VIDEO_MODEL,
)

logger = logging.getLogger(__name__)

_UNSUPPORTED = {"error": "UNSUPPORTED_ON_PROVIDER: DeepInfra does not implement this operation"}


def _image_ok(url: str, media_id: str | None = None) -> dict:
    mid = media_id or url
    return {
        "data": {
            "media": [{
                "name": mid,
                "image": {"generatedImage": {"mediaId": mid, "fifeUrl": url}},
            }]
        }
    }


def _video_ok(url: str, media_id: str, job_name: str) -> dict:
    return {
        "data": {
            "operations": [{
                "status": "MEDIA_GENERATION_STATUS_SUCCESSFUL",
                "operation": {
                    "name": job_name,
                    "metadata": {"video": {"mediaId": media_id, "fifeUrl": url}},
                },
            }]
        }
    }


def _video_pending(job_name: str) -> dict:
    return {
        "data": {
            "operations": [{
                "status": "MEDIA_GENERATION_STATUS_PENDING",
                "operation": {"name": job_name, "metadata": {"video": {}}},
            }]
        }
    }


def _aspect_size(aspect_ratio: str) -> str:
    if "PORTRAIT" in (aspect_ratio or ""):
        return "768x1344"
    return "1344x768"


class DeepInfraBackend:
    name = "deepinfra"

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        image_model: str | None = None,
        video_model: str | None = None,
        session: aiohttp.ClientSession | None = None,
    ):
        self._api_key = api_key if api_key is not None else DEEPINFRA_API_KEY
        self._base = (base_url or DEEPINFRA_BASE_URL).rstrip("/")
        self._image_model = image_model or DEEPINFRA_IMAGE_MODEL
        self._video_model = video_model or DEEPINFRA_VIDEO_MODEL
        self._session = session

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }

    def _require_key(self) -> dict | None:
        if not self._api_key:
            return {"error": "DEEPINFRA_API_KEY missing"}
        return None

    async def _request(self, method: str, path: str, json_body: dict | None = None) -> dict:
        url = path if path.startswith("http") else urljoin(self._base + "/", path.lstrip("/"))
        if self._session is not None:
            async with self._session.request(method, url, headers=self._headers(), json=json_body) as resp:
                data = await resp.json(content_type=None)
                if resp.status >= 400:
                    return {"error": data if isinstance(data, str) else data.get("error", data), "status": resp.status}
                return data if isinstance(data, dict) else {"data": data}

        timeout = aiohttp.ClientTimeout(total=180)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.request(method, url, headers=self._headers(), json=json_body) as resp:
                data = await resp.json(content_type=None)
                if resp.status >= 400:
                    err = data if isinstance(data, str) else (data.get("error") if isinstance(data, dict) else data)
                    return {"error": err, "status": resp.status}
                return data if isinstance(data, dict) else {"data": data}

    def _extract_image_url(self, data: dict) -> str:
        if data.get("url"):
            return data["url"]
        images = data.get("images") or data.get("output") or []
        if isinstance(images, list) and images:
            first = images[0]
            if isinstance(first, str):
                return first
            if isinstance(first, dict):
                return first.get("url") or first.get("image") or ""
        inner = data.get("data")
        if isinstance(inner, list) and inner:
            return inner[0].get("url", "") if isinstance(inner[0], dict) else ""
        if isinstance(inner, dict):
            return inner.get("url") or (inner.get("images") or [""])[0]
        return ""

    async def generate_images(
        self,
        prompt: str,
        project_id: str,
        aspect_ratio: str = "IMAGE_ASPECT_RATIO_LANDSCAPE",
        user_paygate_tier: str = "PAYGATE_TIER_ONE",
        character_media_ids: list[str] | None = None,
    ) -> dict:
        missing = self._require_key()
        if missing:
            return missing
        body: dict[str, Any] = {
            "model": self._image_model,
            "prompt": prompt,
            "size": _aspect_size(aspect_ratio),
            "n": 1,
        }
        if character_media_ids:
            # DeepInfra image APIs that accept refs typically take URLs.
            body["image"] = character_media_ids[0]
        data = await self._request("POST", "/v1/openai/images/generations", body)
        if data.get("error"):
            return data
        url = self._extract_image_url(data)
        if not url:
            return {"error": f"DeepInfra image response had no URL: {str(data)[:300]}"}
        return _image_ok(url)

    async def edit_image(
        self,
        prompt: str,
        source_media_id: str,
        project_id: str,
        aspect_ratio: str = "IMAGE_ASPECT_RATIO_LANDSCAPE",
        user_paygate_tier: str = "PAYGATE_TIER_ONE",
        character_media_ids: list[str] | None = None,
    ) -> dict:
        missing = self._require_key()
        if missing:
            return missing
        body: dict[str, Any] = {
            "model": self._image_model,
            "prompt": prompt,
            "size": _aspect_size(aspect_ratio),
            "image": source_media_id,
            "n": 1,
        }
        data = await self._request("POST", "/v1/openai/images/edits", body)
        if data.get("error") and data.get("status") == 404:
            # Fall back to generations with a source hint in the prompt.
            return await self.generate_images(
                prompt=f"{prompt}. Match composition of reference image.",
                project_id=project_id,
                aspect_ratio=aspect_ratio,
                character_media_ids=[source_media_id] + list(character_media_ids or []),
            )
        if data.get("error"):
            return data
        url = self._extract_image_url(data)
        if not url:
            return {"error": f"DeepInfra edit response had no URL: {str(data)[:300]}"}
        return _image_ok(url)

    def _video_aspect(self, aspect_ratio: str) -> str:
        return "9:16" if "PORTRAIT" in (aspect_ratio or "") else "16:9"

    async def generate_video(
        self,
        start_image_media_id: str,
        prompt: str,
        project_id: str,
        scene_id: str = "",
        aspect_ratio: str = "VIDEO_ASPECT_RATIO_LANDSCAPE",
        end_image_media_id: str | None = None,
        user_paygate_tier: str = "PAYGATE_TIER_ONE",
    ) -> dict:
        missing = self._require_key()
        if missing:
            return missing
        body: dict[str, Any] = {
            "model": self._video_model,
            "prompt": prompt,
            "seconds": "8",
            "size": "720x1280" if "PORTRAIT" in (aspect_ratio or "") else "1280x720",
        }
        if start_image_media_id:
            body["input_reference"] = start_image_media_id
        if end_image_media_id:
            logger.info("DeepInfra: end frame set but API uses start frame only (job still submitted)")
        data = await self._request("POST", "/v1/openai/videos", body)
        if data.get("error"):
            return data
        job_id = data.get("id") or data.get("request_id") or ""
        status = (data.get("status") or "").lower()
        url = ""
        if isinstance(data.get("video"), dict):
            url = data["video"].get("url") or ""
        url = url or data.get("url") or self._extract_image_url(data)
        if status in ("completed", "succeeded", "success") and url:
            return _video_ok(url, job_id or url, job_id or url)
        if not job_id:
            if url:
                return _video_ok(url, url, url)
            return {"error": f"DeepInfra video submit returned no job id: {str(data)[:300]}"}
        return _video_pending(job_id)

    async def generate_video_from_references(self, *args, **kwargs) -> dict:
        return dict(_UNSUPPORTED)

    async def upscale_video(self, *args, **kwargs) -> dict:
        return dict(_UNSUPPORTED)

    async def check_video_status(self, operations: list[dict]) -> dict:
        missing = self._require_key()
        if missing:
            return missing
        out = []
        for op in operations:
            job_id = (op.get("operation") or {}).get("name") or ""
            if not job_id:
                out.append({**op, "status": "MEDIA_GENERATION_STATUS_FAILED"})
                continue
            data = await self._request("GET", f"/v1/openai/videos/{job_id}")
            if data.get("error"):
                return data
            status = (data.get("status") or "").lower()
            url = ""
            if isinstance(data.get("video"), dict):
                url = data["video"].get("url") or ""
            url = url or data.get("url") or ""
            if status in ("completed", "succeeded", "success") and url:
                out.append({
                    "status": "MEDIA_GENERATION_STATUS_SUCCESSFUL",
                    "operation": {
                        "name": job_id,
                        "metadata": {"video": {"mediaId": job_id, "fifeUrl": url}},
                    },
                })
            elif status in ("failed", "error", "cancelled"):
                out.append({
                    "status": "MEDIA_GENERATION_STATUS_FAILED",
                    "operation": {"name": job_id},
                    "error": data.get("error") or status,
                })
            else:
                out.append({
                    "status": "MEDIA_GENERATION_STATUS_PENDING",
                    "operation": {"name": job_id},
                })
        return {"data": {"operations": out}}

    async def upload_image(self, image_bytes: bytes, project_id: str, mime: str = "image/png") -> dict:
        return {"error": "DeepInfra does not use Flow uploadImage — pass image URLs as media_id"}
