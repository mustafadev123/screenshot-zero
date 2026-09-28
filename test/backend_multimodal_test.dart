import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/features/analysis/multimodal/backend_multimodal_service.dart';
import 'package:screenshot_zero/features/analysis/multimodal/hybrid_analysis.dart';

import 'multimodal_test.dart' show MemoryConsent, image, local, response;

void main() {
  final bytes = File('test/fixtures/selected.png').readAsBytesSync();
  test(
    'multipart backend request returns descriptive Reference and existing item',
    () async {
      var calls = 0;
      final service = BackendMultimodalService(
        baseUrl: 'https://example.test',
        readImage: (_) async => bytes,
        clientFactory: () => MockClient((request) async {
          calls++;
          expect(request.url.toString(), 'https://example.test/v1/analyze');
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );
          final multipartBody = latin1.decode(request.bodyBytes);
          expect(multipartBody, contains('name="ocr_text"'));
          expect(multipartBody, contains('name="local_metadata_json"'));
          expect(multipartBody, contains('filename="screenshot.png"'));
          expect(request.headers.containsKey('authorization'), false);
          return http.Response(response(), 200);
        }),
      );
      final result = await HybridAnalysis(
        service: service,
        consent: MemoryConsent(true),
      ).refine(image: image, local: local(), isPro: true);
      expect(result.toItem(id: 1, image: image).title, 'Food photo');
      expect(result.intent, ScreenshotIntent.reference);
      expect(calls, 1);
    },
  );
  for (final scenario in [
    ('product', 'shopping_controls'),
    ('event', 'event_details'),
  ]) {
    test('backend ${scenario.$1} integrates into ScreenshotItem', () async {
      final service = BackendMultimodalService(
        baseUrl: 'https://example.test',
        readImage: (_) async => bytes,
        clientFactory: () => MockClient(
          (_) async => http.Response(
            response(category: scenario.$1, evidence: [scenario.$2]),
            200,
          ),
        ),
      );
      final result = await HybridAnalysis(
        service: service,
        consent: MemoryConsent(true),
      ).refine(image: image, local: local(), isPro: true);
      expect(result.toItem(id: 1, image: image).intent.name, scenario.$1);
    });
  }
  for (final failure in ['timeout', 'http500', 'malformed', 'oversized']) {
    test('backend $failure preserves local result', () async {
      final original = local();
      final service = BackendMultimodalService(
        baseUrl: 'https://example.test',
        readImage: (_) async => bytes,
        timeout: const Duration(milliseconds: 10),
        clientFactory: () => MockClient((_) async {
          if (failure == 'timeout') return Completer<http.Response>().future;
          if (failure == 'http500') return http.Response('Server error', 500);
          return http.Response(
            failure == 'oversized' ? 'x' * 16001 : '{bad',
            200,
          );
        }),
      );
      final result = await HybridAnalysis(
        service: service,
        consent: MemoryConsent(true),
      ).refine(image: image, local: original, isPro: true);
      expect(result, same(original));
    });
  }
  for (final gate in ['strong', 'declined', 'free', 'missing_url']) {
    test('$gate prevents even reading image bytes', () async {
      var imageReads = 0;
      var clientCreations = 0;
      final service = BackendMultimodalService(
        baseUrl: gate == 'missing_url' ? '' : 'https://example.test',
        readImage: (_) async {
          imageReads++;
          return bytes;
        },
        clientFactory: () {
          clientCreations++;
          return MockClient((_) async => http.Response(response(), 200));
        },
      );
      final original = local(
        gate == 'strong' ? 'Assignment 8\nDue May 12, 2027\nSubmit PDF' : '',
      );
      final result = await HybridAnalysis(
        service: service,
        consent: MemoryConsent(gate != 'declined'),
      ).refine(image: image, local: original, isPro: gate != 'free');
      expect(result, same(original));
      expect(imageReads, 0);
      expect(clientCreations, 0);
    });
  }
  test(
    'URL validation and release configuration reject cleartext and credentials',
    () {
      for (final url in [
        '',
        'not-url',
        'ftp://example.test',
        'https://user:password@example.test',
        'https://example.test?key=secret',
      ]) {
        expect(BackendMultimodalService(baseUrl: url).available, false);
      }
      expect(
        BackendMultimodalService(
          baseUrl: 'http://10.0.0.70:8000',
          allowHttp: false,
        ).available,
        false,
      );
      expect(
        BackendMultimodalService(
          baseUrl: 'http://10.0.0.70:8000',
          allowHttp: true,
        ).available,
        true,
      );
    },
  );
}
