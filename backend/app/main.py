import asyncio
import io
import json
import time
import warnings
from collections import defaultdict, deque
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from openai import APIError, APITimeoutError
from PIL import Image, UnidentifiedImageError
from pydantic import ValidationError
from starlette.datastructures import UploadFile

from app.config import Settings
from app.services.multimodal_service import ServiceUnavailable
from app.services.openai_multimodal_service import OpenAIMultimodalService


class RequestGuard:
    """Single-process LAN safeguards, including a body cap before multipart parsing."""
    def __init__(self, app, settings):
        self.app, self.settings = app, settings
        self.ip_requests = defaultdict(deque)
        self.daily = deque()
        self.active = 0

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http' or scope['path'] != '/v1/analyze':
            return await self.app(scope, receive, send)
        async def reject(status, detail):
            await JSONResponse({'detail': detail}, status_code=status)(scope, receive, send)
        now = time.monotonic()
        for ip in list(self.ip_requests):
            q = self.ip_requests[ip]
            while q and q[0] < now - 60:
                q.popleft()
            if not q:
                del self.ip_requests[ip]
        while self.daily and self.daily[0] < now - 86400:
            self.daily.popleft()
        ip = (scope.get('client') or ('unknown', 0))[0]
        if (len(self.ip_requests[ip]) >= self.settings.requests_per_minute or
                len(self.daily) >= self.settings.max_requests_per_day or self.active >= 2):
            return await reject(429, 'Analysis request limit reached')
        self.ip_requests[ip].append(now)
        self.daily.append(now)
        self.active += 1
        try:
            body = bytearray()
            try:
                async with asyncio.timeout(10):
                    while True:
                        part = await receive()
                        if part['type'] == 'http.disconnect':
                            return
                        body.extend(part.get('body', b''))
                        if len(body) > self.settings.max_image_bytes + 32768:
                            return await reject(413, 'Upload too large')
                        if not part.get('more_body', False):
                            break
            except TimeoutError:
                return await reject(408, 'Upload timed out')
            delivered = False
            async def replay():
                nonlocal delivered
                if not delivered:
                    delivered = True
                    return {'type': 'http.request', 'body': bytes(body), 'more_body': False}
                return await receive()
            await self.app(scope, replay, send)
        finally:
            self.active -= 1


def create_app(settings=None, service=None):
    settings = settings or Settings.from_env()
    service = service or OpenAIMultimodalService(settings)

    @asynccontextmanager
    async def lifespan(app):
        yield
        if isinstance(service, OpenAIMultimodalService):
            await service.close()

    app = FastAPI(lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None)
    app.add_middleware(RequestGuard, settings=settings)

    @app.get('/health')
    async def health():
        return {'status': 'ok'}

    @app.post('/v1/analyze')
    async def analyze(request: Request):
        if not request.headers.get('content-type', '').startswith('multipart/form-data'):
            raise HTTPException(415, 'Expected multipart form data')
        async with request.form(max_files=1, max_fields=5, max_part_size=16000) as form:
            allowed = {'image', 'ocr_text', 'local_category', 'local_confidence', 'local_title', 'local_metadata_json'}
            if set(form) - allowed or len(form.multi_items()) != len(form):
                raise HTTPException(422, 'Invalid form fields')
            image = form.get('image')
            if not isinstance(image, UploadFile):
                raise HTTPException(422, 'Image required')
            types = {'image/png': 'PNG', 'image/jpeg': 'JPEG', 'image/webp': 'WEBP'}
            if image.content_type not in types:
                raise HTTPException(415, 'Unsupported image type')
            raw = await image.read(settings.max_image_bytes + 1)
            if not raw or len(raw) > settings.max_image_bytes:
                raise HTTPException(413, 'Invalid image size')
            try:
                with warnings.catch_warnings():
                    warnings.simplefilter('error', Image.DecompressionBombWarning)
                    with Image.open(io.BytesIO(raw)) as picture:
                        if picture.format != types[image.content_type] or picture.width * picture.height > settings.max_pixels or getattr(picture, 'n_frames', 1) != 1:
                            raise ValueError('Invalid image')
                        picture.verify()
            except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
                raise HTTPException(415, 'Invalid screenshot image') from None
            try:
                text = form['ocr_text']
                category = form['local_category']
                confidence = float(form['local_confidence'])
                title = form.get('local_title', '')
                metadata = json.loads(form.get('local_metadata_json', '{}'))
                if (not isinstance(text, str) or len(text) > 12000 or
                    category not in {'event', 'place', 'product', 'read', 'task', 'reference'} or
                    not 0 <= confidence <= 1 or not isinstance(title, str) or len(title) > 300 or
                    not isinstance(metadata, dict) or len(metadata) > 30 or
                    any(not isinstance(k, str) or len(k) > 100 or not isinstance(v, str) or len(v) > 500 for k, v in metadata.items())):
                    raise ValueError('Invalid context')
            except (KeyError, TypeError, ValueError):
                raise HTTPException(422, 'Invalid local analysis metadata') from None
            context = {'ocr_text': text, 'local_category': category, 'local_confidence': confidence,
                       'local_title': title, 'local_metadata': metadata}
            try:
                result = await asyncio.wait_for(service.analyze(raw, image.content_type, context), settings.timeout_seconds)
                return result.flutter_json()
            except ServiceUnavailable:
                raise HTTPException(503, 'Visual analysis unavailable') from None
            except (TimeoutError, APITimeoutError):
                raise HTTPException(504, 'Visual analysis timed out') from None
            except (APIError, ValidationError, ValueError):
                raise HTTPException(502, 'Visual analysis failed') from None

    return app


app = create_app()
