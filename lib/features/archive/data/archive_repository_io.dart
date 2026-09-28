import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../domain/models/imported_image.dart';
import '../../../domain/models/screenshot_item.dart';
import 'archive_repository.dart';
import 'archive_record.dart';

ArchiveRepository createArchiveRepository() => FileArchiveRepository();

class FileArchiveRepository implements ArchiveRepository {
  FileArchiveRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  Future<Directory> _root() async {
    final support = await _directory();
    return Directory('${support.path}/screenshot_zero_archive')
        .create(recursive: true);
  }

  static final _imageName = RegExp(r'^[a-f0-9]{64}\.image$');
  static final _recordId = RegExp(r'^[a-f0-9]{32}$');

  @override
  Future<void> clearDevelopment() async {
    if (!kDebugMode) throw StateError('Development only');
    final root = await _root();
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileSystemException('Unexpected archive directory');
    }
    // Only this app's dedicated archive; never picker sources or other support files.
    await root.delete(recursive: true);
  }

  @override
  Future<List<ScreenshotItem>> load() async {
    final root = await _root();
    final result = <ScreenshotItem>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final data =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final name = data['imageFile'] as String;
        if (!_imageName.hasMatch(name) ||
            !_recordId.hasMatch(data['archiveId'] as String)) {
          throw const FormatException('Invalid archive identity');
        }
        // Keep metadata even when an image is missing; the image widget has
        // an existing graceful placeholder. Never delete malformed records.
        result.add(ArchiveRecord.decode(data, '${root.path}/images/$name'));
      } catch (_) {
        if (kDebugMode) {
          debugPrint(
            'Archive: skipped an unreadable record; original retained.',
          );
        }
      }
    }
    return result;
  }

  @override
  Future<ScreenshotItem> save(ScreenshotItem item) async {
    if (!item.processed ||
        item.importedImage == null ||
        !_recordId.hasMatch(item.archiveId ?? '')) {
      throw const FormatException('Only completed real items can be archived');
    }
    final root = await _root();
    final images = await Directory('${root.path}/images')
        .create(recursive: true);
    final source = File(item.importedImage!.path);
    final digest = await sha256.bind(source.openRead()).first;
    final name = '$digest.image';
    final destination = File('${images.path}/$name');
    if (!await destination.exists()) {
      final tempImage = await source.copy(
        '${destination.path}.${item.archiveId}.tmp',
      );
      await tempImage.rename(destination.path);
    }
    final stored = item.withStorage(
      archiveId: item.archiveId!,
      image: ImportedImage(
        path: destination.path,
        name: item.importedImage!.name,
      ),
    );
    final record = File('${root.path}/${item.archiveId}.json');
    // Each record is independent, preventing one damaged JSON from wiping
    // the entire archive. A retry never replaces an existing completed record.
    if (!await record.exists()) {
      final temporary = File('${record.path}.tmp');
      await temporary.writeAsString(
        jsonEncode(ArchiveRecord.encode(stored, name)),
        flush: true,
      );
      await temporary.rename(record.path);
    }
    return stored;
  }
}
