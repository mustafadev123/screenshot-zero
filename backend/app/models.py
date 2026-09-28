from typing import Annotated, Literal
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict, Field, field_validator

Category = Literal['event', 'place', 'product', 'read', 'task', 'reference']
Evidence = Literal['shopping_controls', 'event_details', 'place_listing',
                   'article_layout', 'task_instructions']
Detail = Annotated[str, Field(min_length=1, max_length=300)]


class AnalysisResult(BaseModel):
    # All properties required for strict Structured Outputs; missing facts are null.
    model_config = ConfigDict(extra='forbid', strict=True)
    category: Category
    title: str = Field(min_length=1, max_length=100)
    confidence: float = Field(ge=0, le=1, allow_inf_nan=False)
    reason: str = Field(min_length=1, max_length=500)
    evidence: list[Evidence] = Field(max_length=5)
    date: Detail | None
    time: Detail | None
    venue: Detail | None
    address: Detail | None
    price: Detail | None
    variant: Detail | None
    size: Detail | None
    author: Detail | None
    publication: Detail | None
    url: Detail | None
    due_date: Detail | None
    due_time: Detail | None

    @field_validator('*')
    @classmethod
    def clean_strings(cls, value):
        if isinstance(value, str):
            if not value.strip() or any(ord(char) < 32 for char in value):
                raise ValueError('Invalid text')
            return value.strip()
        return value

    @field_validator('url')
    @classmethod
    def safe_url(cls, value):
        if value is not None:
            parsed = urlsplit(value)
            if parsed.scheme not in ('https', 'http') or not parsed.hostname or parsed.username or parsed.password:
                raise ValueError('Invalid URL')
        return value

    def flutter_json(self):
        result = self.model_dump(exclude_none=True)
        for original, renamed in [('due_date', 'dueDate'), ('due_time', 'dueTime')]:
            if original in result:
                result[renamed] = result.pop(original)
        return result
