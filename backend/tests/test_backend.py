import asyncio
import io
from types import SimpleNamespace
from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi.testclient import TestClient
from openai import APIConnectionError, APITimeoutError, AsyncOpenAI
from PIL import Image

from app.config import Settings
from app.main import create_app
from app.models import AnalysisResult
from app.services.openai_multimodal_service import OpenAIMultimodalService


def output(category='reference', **extra):
    values = {name: None for name in AnalysisResult.model_fields}
    values.update(category=category, title='Food photo' if category == 'reference' else 'Running shoes',
                  confidence=.9, reason='Visible evidence', evidence=[])
    values.update(extra)
    return AnalysisResult(**values)


def png():
    stream = io.BytesIO()
    Image.new('RGB', (12, 12)).save(stream, format='PNG')
    return stream.getvalue()


def post(client, *, data=None, image=None, mime='image/png'):
    fields = {'ocr_text': '', 'local_category': 'reference', 'local_confidence': '0',
              'local_metadata_json': '{}'}
    fields.update(data or {})
    return client.post('/v1/analyze', data=fields,
                       files={'image': ('screenshot.png', png() if image is None else image, mime)})


def harness(result=None, error=None, **settings):
    parse = AsyncMock(return_value=SimpleNamespace(status='completed', output_parsed=result or output()), side_effect=error)
    upstream = SimpleNamespace(responses=SimpleNamespace(parse=parse), close=AsyncMock())
    config = Settings(**settings)
    service = OpenAIMultimodalService(config, client=upstream)
    return TestClient(create_app(config, service)), parse


def test_health_has_no_configuration():
    client, parse = harness()
    assert client.get('/health').json() == {'status': 'ok'}
    parse.assert_not_called()


@pytest.mark.parametrize('category', ['reference', 'product'])
def test_valid_response_and_sdk_request(category):
    client, parse = harness(output(category, evidence=['shopping_controls'] if category == 'product' else []))
    response = post(client)
    assert response.status_code == 200
    assert response.json()['category'] == category
    assert 'date' not in response.json()
    args = parse.call_args.kwargs
    assert args['store'] is False and args['max_output_tokens'] == 800
    assert args['text_format'] is AnalysisResult
    assert args['input'][0]['content'][1]['image_url'].startswith('data:image/png;base64,')
    assert 'Object recognition alone' in args['instructions']


def test_due_fields_match_existing_flutter_contract():
    client, _ = harness(output('task', due_date='May 12, 2027', due_time='7 PM', evidence=['task_instructions']))
    data = post(client).json()
    assert data['dueDate'] == 'May 12, 2027' and 'due_date' not in data


@pytest.mark.parametrize('kwargs,status', [
    ({'mime': 'text/plain'}, 415),
    ({'image': b'not an image'}, 415),
    ({'data': {'local_metadata_json': '['}}, 422),
    ({'data': {'local_metadata_json': '[]'}}, 422),
    ({'data': {'local_metadata_json': '{"key":{}}'}}, 422),
    ({'data': {'local_category': 'invented'}}, 422),
    ({'data': {'local_confidence': 'NaN'}}, 422),
    ({'data': {'ocr_text': 'x' * 12001}}, 422),
])
def test_invalid_inputs_never_call_model(kwargs, status):
    client, parse = harness()
    assert post(client, **kwargs).status_code == status
    parse.assert_not_called()


def test_missing_image():
    client, parse = harness()
    response = client.post('/v1/analyze', files={'other': ('', 'value')})
    assert response.status_code == 422
    parse.assert_not_called()


def test_oversized_image_and_entire_body():
    client, parse = harness(max_image_bytes=20)
    assert post(client).status_code == 413
    assert client.post('/v1/analyze', content=b'x' * 40000).status_code == 413
    parse.assert_not_called()


@pytest.mark.parametrize('error,status', [
    (ValueError('sensitive model output'), 502),
    (APITimeoutError(request=httpx.Request('POST', 'https://api.openai.com')), 504),
    (APIConnectionError(request=httpx.Request('POST', 'https://api.openai.com')), 502),
])
def test_upstream_failures_are_sanitized(error, status):
    client, parse = harness(error=error)
    result = post(client)
    assert result.status_code == status
    assert 'sensitive' not in result.text
    assert parse.call_count == 1


def test_malformed_and_refused_model_result():
    client, parse = harness()
    parse.return_value.output_parsed = {'category': 'nonsense'}
    assert post(client).status_code == 502
    parse.return_value.output_parsed = None
    assert post(client).status_code == 502


def test_bounded_timeout():
    client, parse = harness(timeout_seconds=.01)
    async def slow(**kwargs):
        await asyncio.sleep(1)
    parse.side_effect = slow
    assert post(client).status_code == 504


def test_no_key_is_safe_and_health_stays_available():
    client = TestClient(create_app(Settings(api_key='')))
    assert client.get('/health').status_code == 200
    assert post(client).status_code == 503


def test_rate_and_daily_limits():
    client, parse = harness(requests_per_minute=1)
    assert post(client).status_code == 200
    assert post(client).status_code == 429
    assert parse.call_count == 1
    other, _ = harness(max_requests_per_day=1)
    assert post(other).status_code == 200
    assert post(other).status_code == 429


def test_actual_sdk_serializes_strict_schema_and_parses_mocked_response():
    # Exercise the real SDK over a mock transport, not a live OpenAI call.
    import json
    async def run():
        def transport(request):
            body = json.loads(request.content)
            assert body['text']['format']['strict'] is True
            assert body['text']['format']['schema']['additionalProperties'] is False
            return httpx.Response(200, json={
                'id': 'resp_mock', 'object': 'response', 'created_at': 1,
                'status': 'completed', 'model': 'gpt-4.1-mini',
                'output': [{'type': 'message', 'id': 'msg_mock', 'role': 'assistant', 'status': 'completed',
                    'content': [{'type': 'output_text', 'text': output().model_dump_json(), 'annotations': []}]}],
            })
        async with AsyncOpenAI(api_key='mock-only', max_retries=0,
            http_client=httpx.AsyncClient(transport=httpx.MockTransport(transport))) as client:
            service = OpenAIMultimodalService(Settings(), client)
            result = await service.analyze(png(), 'image/png', {})
            assert result.title == 'Food photo'
    asyncio.run(run())
