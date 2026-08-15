"""MediaBackend protocol — same method names as FlowClient for the ops we use."""

from __future__ import annotations

from typing import Optional, Protocol, runtime_checkable


@runtime_checkable
class MediaBackend(Protocol):
    """Submit/status surface shared by Flow and HTTP providers."""

    name: str

    async def generate_images(
        self,
        prompt: str,
        project_id: str,
        aspect_ratio: str = "IMAGE_ASPECT_RATIO_LANDSCAPE",
        user_paygate_tier: str = "PAYGATE_TIER_ONE",
        character_media_ids: list[str] | None = None,
    ) -> dict: ...

    async def edit_image(
        self,
        prompt: str,
        source_media_id: str,
        project_id: str,
        aspect_ratio: str = "IMAGE_ASPECT_RATIO_LANDSCAPE",
        user_paygate_tier: str = "PAYGATE_TIER_ONE",
        character_media_ids: list[str] | None = None,
    ) -> dict: ...

    async def generate_video(
        self,
        start_image_media_id: str,
        prompt: str,
        project_id: str,
        scene_id: str = "",
        aspect_ratio: str = "VIDEO_ASPECT_RATIO_LANDSCAPE",
        end_image_media_id: str | None = None,
        user_paygate_tier: str = "PAYGATE_TIER_ONE",
    ) -> dict: ...

    async def generate_video_from_references(
        self,
        reference_media_ids: list[str],
        prompt: str,
        project_id: str,
        scene_id: str = "",
        aspect_ratio: str = "VIDEO_ASPECT_RATIO_LANDSCAPE",
        user_paygate_tier: str = "PAYGATE_TIER_ONE",
    ) -> dict: ...

    async def upscale_video(
        self,
        media_id: str,
        scene_id: str = "",
        aspect_ratio: str = "VIDEO_ASPECT_RATIO_LANDSCAPE",
    ) -> dict: ...

    async def check_video_status(self, operations: list[dict]) -> dict: ...

    async def upload_image(
        self, image_bytes: bytes, project_id: str, mime: str = "image/png"
    ) -> dict: ...
