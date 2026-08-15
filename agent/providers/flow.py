"""Flow backend — thin wrap of the existing FlowClient."""

from __future__ import annotations


class FlowBackend:
    name = "flow"

    def __init__(self, flow_client):
        self._client = flow_client

    async def generate_images(self, *args, **kwargs):
        return await self._client.generate_images(*args, **kwargs)

    async def edit_image(self, *args, **kwargs):
        return await self._client.edit_image(*args, **kwargs)

    async def generate_video(self, *args, **kwargs):
        return await self._client.generate_video(*args, **kwargs)

    async def generate_video_from_references(self, *args, **kwargs):
        return await self._client.generate_video_from_references(*args, **kwargs)

    async def upscale_video(self, *args, **kwargs):
        return await self._client.upscale_video(*args, **kwargs)

    async def check_video_status(self, operations):
        return await self._client.check_video_status(operations)

    async def upload_image(self, *args, **kwargs):
        return await self._client.upload_image(*args, **kwargs)
