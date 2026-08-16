from pydantic import BaseModel, field_serializer
from typing import Optional
from agent.models.enums import ChainType, SceneSource, StatusType

# JSON null + s.get(key, "")[:n] crashes (default is skipped when key exists).
_NULL_SAFE_STRING_FIELDS = (
    "vertical_image_media_id",
    "vertical_video_media_id",
    "vertical_upscale_media_id",
    "horizontal_image_media_id",
    "horizontal_video_media_id",
    "horizontal_upscale_media_id",
    "vertical_end_scene_media_id",
    "horizontal_end_scene_media_id",
    "vertical_image_url",
    "vertical_video_url",
    "vertical_upscale_url",
    "horizontal_image_url",
    "horizontal_video_url",
    "horizontal_upscale_url",
)


class SceneCreate(BaseModel):
    video_id: str
    display_order: int = 0
    prompt: str
    image_prompt: Optional[str] = None
    video_prompt: Optional[str] = None
    transition_prompt: Optional[str] = None
    character_names: Optional[list[str]] = None
    parent_scene_id: Optional[str] = None
    chain_type: ChainType = "ROOT"
    source: Optional[SceneSource] = None


class SceneUpdate(BaseModel):
    prompt: Optional[str] = None
    image_prompt: Optional[str] = None
    video_prompt: Optional[str] = None
    character_names: Optional[list[str]] = None
    parent_scene_id: Optional[str] = None
    chain_type: Optional[ChainType] = None
    source: Optional[SceneSource] = None
    display_order: Optional[int] = None

    vertical_image_url: Optional[str] = None
    vertical_image_media_id: Optional[str] = None
    vertical_image_status: Optional[StatusType] = None
    vertical_video_url: Optional[str] = None
    vertical_video_media_id: Optional[str] = None
    vertical_video_status: Optional[StatusType] = None
    vertical_upscale_url: Optional[str] = None
    vertical_upscale_media_id: Optional[str] = None
    vertical_upscale_status: Optional[StatusType] = None

    horizontal_image_url: Optional[str] = None
    horizontal_image_media_id: Optional[str] = None
    horizontal_image_status: Optional[StatusType] = None
    horizontal_video_url: Optional[str] = None
    horizontal_video_media_id: Optional[str] = None
    horizontal_video_status: Optional[StatusType] = None
    horizontal_upscale_url: Optional[str] = None
    horizontal_upscale_media_id: Optional[str] = None
    horizontal_upscale_status: Optional[StatusType] = None

    vertical_end_scene_media_id: Optional[str] = None
    horizontal_end_scene_media_id: Optional[str] = None

    transition_prompt: Optional[str] = None

    trim_start: Optional[float] = None
    trim_end: Optional[float] = None
    duration: Optional[float] = None
    narrator_text: Optional[str] = None


class Scene(BaseModel):
    id: str
    video_id: str
    display_order: int = 0
    prompt: Optional[str] = None
    image_prompt: Optional[str] = None
    video_prompt: Optional[str] = None
    character_names: Optional[list[str]] = None  # parsed from JSON
    parent_scene_id: Optional[str] = None
    chain_type: str = "ROOT"
    source: Optional[str] = "root"

    vertical_image_url: Optional[str] = None
    vertical_image_media_id: Optional[str] = None
    vertical_image_status: str = "PENDING"
    vertical_video_url: Optional[str] = None
    vertical_video_media_id: Optional[str] = None
    vertical_video_status: str = "PENDING"
    vertical_upscale_url: Optional[str] = None
    vertical_upscale_media_id: Optional[str] = None
    vertical_upscale_status: str = "PENDING"

    horizontal_image_url: Optional[str] = None
    horizontal_image_media_id: Optional[str] = None
    horizontal_image_status: str = "PENDING"
    horizontal_video_url: Optional[str] = None
    horizontal_video_media_id: Optional[str] = None
    horizontal_video_status: str = "PENDING"
    horizontal_upscale_url: Optional[str] = None
    horizontal_upscale_media_id: Optional[str] = None
    horizontal_upscale_status: str = "PENDING"

    vertical_end_scene_media_id: Optional[str] = None
    horizontal_end_scene_media_id: Optional[str] = None

    transition_prompt: Optional[str] = None

    trim_start: Optional[float] = None
    trim_end: Optional[float] = None
    duration: Optional[float] = None
    narrator_text: Optional[str] = None

    created_at: Optional[str] = None
    updated_at: Optional[str] = None

    @field_serializer(*_NULL_SAFE_STRING_FIELDS)
    def _serialize_optional_text(self, value: Optional[str]) -> str:
        return value or ""
