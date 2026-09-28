from typing import Protocol

from app.models import AnalysisResult


class MultimodalService(Protocol):
    async def analyze(self, image: bytes, mime: str, context: dict) -> AnalysisResult: ...


class ServiceUnavailable(Exception):
    pass
