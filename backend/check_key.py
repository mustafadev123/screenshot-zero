"""Check credentials without uploading screenshots or printing API error bodies."""
import asyncio

from openai import APIError, AsyncOpenAI

from app.config import Settings


async def main():
    settings = Settings.from_env()
    if not settings.api_key:
        print('OPENAI_API_KEY is missing')
        return
    try:
        async with AsyncOpenAI(api_key=settings.api_key, max_retries=0, timeout=15) as client:
            await client.models.retrieve(settings.model)
        print('Credential/model lookup succeeded; live image analysis not tested')
    except APIError as error:
        print(f'OpenAI credential/model check failed: HTTP {getattr(error, "status_code", "unavailable")}')


if __name__ == '__main__':
    asyncio.run(main())
