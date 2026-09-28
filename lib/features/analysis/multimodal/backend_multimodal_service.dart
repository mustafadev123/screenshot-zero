import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/models/imported_image.dart';
import 'multimodal_service.dart';

class BackendMultimodalService implements MultimodalAnalysisService {
  BackendMultimodalService({
    required String baseUrl,
    bool allowHttp = kDebugMode,
    this.timeout = const Duration(seconds: 22),
    http.Client Function()? clientFactory,
    Future<Uint8List> Function(ImportedImage)? readImage,
  }) : endpoint = _endpoint(baseUrl, allowHttp),
       _clientFactory = clientFactory ?? http.Client.new,
       _readImage = readImage ?? _read;

  static const maxImageBytes = 8 * 1024 * 1024;
  final Uri? endpoint;
  final Duration timeout;
  final http.Client Function() _clientFactory;
  final Future<Uint8List> Function(ImportedImage) _readImage;

  static Uri? _endpoint(String value, bool allowHttp) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(uri.scheme == 'https' || allowHttp && uri.scheme == 'http')) {
      return null;
    }
    return uri.replace(
      path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/v1/analyze',
    );
  }

  static Future<Uint8List> _read(ImportedImage image) async {
    final file = XFile(image.path);
    if (await file.length() > maxImageBytes) {
      throw const FormatException('Image too large');
    }
    return file.readAsBytes();
  }

  @override
  bool get available => endpoint != null;

  @override
  Future<MultimodalResult> analyze(MultimodalRequest request) async {
    if (!available) throw StateError('Backend unavailable');
    final client = _clientFactory();
    var active = true;
    Future<MultimodalResult> send() async {
      final bytes = await _readImage(request.image);
      if (!active) throw StateError('Request expired');
      if (bytes.isEmpty || bytes.length > maxImageBytes) {
        throw const FormatException('Invalid image size');
      }
      final type =
          bytes.length >= 8 &&
              bytes.take(8).join(',') == '137,80,78,71,13,10,26,10'
          ? 'png'
          : bytes.length >= 3 &&
                bytes[0] == 255 &&
                bytes[1] == 216 &&
                bytes[2] == 255
          ? 'jpeg'
          : bytes.length >= 12 &&
                ascii.decode(bytes.sublist(0, 4), allowInvalid: true) ==
                    'RIFF' &&
                ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP'
          ? 'webp'
          : null;
      if (type == null) throw const FormatException('Unsupported image');
      String limit(String text, int length) =>
          text.length <= length ? text : text.substring(0, length);
      final context = <String, String>{};
      for (final entry in request.local.extractedFields.entries.take(30)) {
        if (entry.key.length <= 100) {
          context[entry.key] = limit(entry.value, 500);
        }
      }
      final multipart = http.MultipartRequest('POST', endpoint!)
        ..followRedirects = false
        ..fields.addAll({
          'ocr_text': limit(request.ocrText, 12000),
          'local_category': request.local.intent.name,
          'local_confidence': request.local.confidence.toString(),
          'local_title': limit(request.local.title, 300),
          'local_metadata_json': jsonEncode(context),
        })
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: 'screenshot.$type',
            contentType: MediaType('image', type),
          ),
        );
      final response = await client.send(multipart);
      if (response.statusCode != 200) {
        throw StateError('Backend analysis failed');
      }
      final output = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (output.length + chunk.length > 16000) {
          throw const FormatException('Response too large');
        }
        output.add(chunk);
      }
      return MultimodalResult.fromJson(utf8.decode(output.takeBytes()));
    }

    try {
      return await send().timeout(timeout);
    } finally {
      active = false;
      client.close();
    }
  }
}
