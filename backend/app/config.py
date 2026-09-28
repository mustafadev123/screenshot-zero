import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv


@dataclass(frozen=True)
class Settings:
    api_key: str = field(default='', repr=False)
    model: str = 'gpt-4.1-mini'
    max_image_bytes: int = 8 * 1024 * 1024
    max_pixels: int = 20_000_000
    timeout_seconds: float = 18
    requests_per_minute: int = 6
    max_requests_per_day: int = 100

    @classmethod
    def from_env(cls):
        load_dotenv(Path(__file__).resolve().parents[1] / '.env', override=False)
        return cls(
            api_key=os.getenv('OPENAI_API_KEY', ''),
            model=os.getenv('OPENAI_MULTIMODAL_MODEL', 'gpt-4.1-mini'),
            requests_per_minute=max(1, int(os.getenv('REQUESTS_PER_MINUTE', '6'))),
            max_requests_per_day=max(1, int(os.getenv('MAX_REQUESTS_PER_DAY', '100'))),
        )
