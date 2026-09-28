import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/domain/models/screenshot_item.dart';
import 'package:screenshot_zero/features/archive/archive_provider.dart';
import 'package:screenshot_zero/features/archive/data/archive_repository.dart';
import 'package:screenshot_zero/features/archive/data/archive_repository_io.dart';
import 'package:screenshot_zero/features/subscription/analysis_quota.dart';
import 'package:screenshot_zero/features/subscription/subscription_service.dart';
import 'package:screenshot_zero/features/zero_stack/inbox_provider.dart';

ScreenshotItem sample(
  String path,
  ScreenshotIntent intent,
  String status, {
  String? id,
}) =>
    ScreenshotItem(
      id: 1,
      title: 'Example',
      subtitle: 'Detected details',
      metadata: const ['Metadata'],
      intent: intent,
      importedImage: ImportedImage(path: path, name: 'original.png'),
      primaryAction: 'Save',
      archiveLabel: 'Saved',
      archiveId: id,
      rawOcrText: 'PRIVATE OCR DIAGNOSTICS',
      matchedSignals: const ['internal_signal'],
      analysisConfidence: .9,
      ocrError: 'private path',
      extractedFields: const {
        'price': r'$89',
        'author': 'Example author',
        'due_date': 'Sep 30, 2026',
        'detected_text': 'PRIVATE OCR DIAGNOSTICS',
      },
      createdAt: DateTime(2026, 9, 27),
    ).complete(
      status: status,
      actionDateTime: intent == ScreenshotIntent.task
          ? DateTime(2030, 9, 30, 23, 59)
          : null,
      notificationId: intent == ScreenshotIntent.task ? 9123 : null,
    );

class FlakyRepository extends MemoryArchiveRepository {
  bool fail = true;
  @override
  Future<ScreenshotItem> save(ScreenshotItem item) {
    if (fail) return Future.error(const FileSystemException('disk full'));
    return super.save(item);
  }
}

class DelayedRepository extends MemoryArchiveRepository {
  final ready = Completer<List<ScreenshotItem>>();
  @override
  Future<List<ScreenshotItem>> load() => ready.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late File original;
  late FileArchiveRepository repository;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('screenshot-zero-test-');
    original = File('${temp.path}/picker.png');
    await original.writeAsBytes(
      await File('test/fixtures/selected.png').readAsBytes(),
    );
    repository = FileArchiveRepository(
      directory: () async => Directory('${temp.path}/support'),
    );
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test(
    'all real statuses survive reload with owned images and no debug data',
    () async {
      final statuses = {
        ScreenshotIntent.event: 'Added to calendar',
        ScreenshotIntent.place: 'Opened in Maps',
        ScreenshotIntent.product: 'Saved to wishlist',
        ScreenshotIntent.read: 'Saved for reading',
        ScreenshotIntent.task: 'Reminder set',
        ScreenshotIntent.reference: 'Saved reference',
      };
      final bytes = await original.readAsBytes();
      var counter = 0;
      for (final entry in statuses.entries) {
        final item = sample(
          original.path,
          entry.key,
          entry.value,
          id: (++counter).toRadixString(16).padLeft(32, '0'),
        );
        final stored = await repository.save(item);
        expect(stored.importedImage!.path, startsWith('${temp.path}/support/'));
        expect(await File(stored.importedImage!.path).readAsBytes(), bytes);
        expect(await original.exists(), isTrue);
      }
      // Simulate the picker cache disappearing after a normal restart.
      await original.delete();
      final reloaded = await FileArchiveRepository(
        directory: () async => Directory('${temp.path}/support'),
      ).load();
      expect(reloaded, hasLength(6));
      for (final item in reloaded) {
        expect(item.disposition, statuses[item.intent]);
        expect(item.createdAt, DateTime(2026, 9, 27));
        expect(item.processedAt, isNotNull);
        expect(item.title, 'Example');
        expect(item.metadata, ['Metadata']);
        expect(item.rawOcrText, isNull);
        expect(item.matchedSignals, isEmpty);
        expect(item.extractedFields.containsKey('detected_text'), isFalse);
        expect(await File(item.importedImage!.path).readAsBytes(), bytes);
        if (item.intent == ScreenshotIntent.task) {
          expect(item.actionDateTime, DateTime(2030, 9, 30, 23, 59));
          expect(item.notificationId, 9123);
        }
      }
      final owned = Directory(
        '${temp.path}/support/screenshot_zero_archive/images',
      );
      expect(
        await owned.list().length,
        1,
        reason: 'same content copied only once',
      );
      final root = owned.parent;
      await for (final file in root.list()) {
        if (file is File && file.path.endsWith('.json')) {
          final content = await file.readAsString();
          expect(content, isNot(contains('PRIVATE OCR')));
          expect(content, isNot(contains(original.path)));
        }
      }
    },
  );

  test('one corrupt record, old optional fields and absent image preserve usable metadata', () async {
    final stored = await repository.save(
      sample(
        original.path,
        ScreenshotIntent.reference,
        'Saved reference',
        id: 'a' * 32,
      ),
    );
    final root = Directory('${temp.path}/support/screenshot_zero_archive');
    await File('${root.path}/broken.json').writeAsString('{broken');
    await File('${root.path}/future.json')
        .writeAsString(jsonEncode({'version': 99}));
    final valid = File('${root.path}/${'a' * 32}.json');
    final data = jsonDecode(await valid.readAsString()) as Map<String, dynamic>;
    data.remove('createdAt');
    data.remove('processedAt');
    data.remove('metadata');
    await valid.writeAsString(jsonEncode(data));
    await File(stored.importedImage!.path).delete();
    final records = await repository.load();
    expect(records, hasLength(1));
    expect(records.single.disposition, 'Saved reference');
    expect(records.single.createdAt, isNull);
    expect(await File('${root.path}/broken.json').exists(), isTrue);
  });

  test(
    'provider restart, new imports and demo reset retain real archive',
    () async {
      final container = ProviderContainer(
        overrides: [archiveRepositoryProvider.overrideWithValue(repository)],
      );
      final real = sample(
        original.path,
        ScreenshotIntent.product,
        'Saved to wishlist',
      );
      expect(await container.read(archiveProvider.notifier).save(real), isTrue);
      container.read(inboxProvider.notifier).reset();
      final demo = container.read(inboxProvider).first;
      await container.read(inboxProvider.notifier).process(demo.id);
      expect(container.read(archiveProvider).items, hasLength(1));
      container.read(inboxProvider.notifier).replaceCollection([]);
      expect(
        container.read(archiveProvider).items.single.disposition,
        'Saved to wishlist',
      );
      container.dispose();
      final restarted = ProviderContainer(
        overrides: [archiveRepositoryProvider.overrideWithValue(repository)],
      );
      await restarted.read(archiveProvider.notifier).ensureReady();
      expect(
        restarted.read(archiveProvider).items.single.disposition,
        'Saved to wishlist',
      );
      restarted.dispose();
    },
  );

  test(
    'late startup load and queued save merge rather than overwrite',
    () async {
      final repo = DelayedRepository();
      final container = ProviderContainer(
        overrides: [archiveRepositoryProvider.overrideWithValue(repo)],
      );
      final controller = container.read(archiveProvider.notifier);
      final saving = controller.save(
        sample(original.path, ScreenshotIntent.read, 'Saved for reading'),
      );
      expect(container.read(archiveProvider).loading, isTrue);
      repo.ready.complete([
        sample(
          original.path,
          ScreenshotIntent.reference,
          'Saved reference',
          id: 'b' * 32,
        ),
      ]);
      expect(await saving, isTrue);
      expect(container.read(archiveProvider).items, hasLength(2));
      container.dispose();
    },
  );

  test(
    'failed disk save retains completed action and retries same identity',
    () async {
      final repo = FlakyRepository();
      final container = ProviderContainer(
        overrides: [archiveRepositoryProvider.overrideWithValue(repo)],
      );
      final controller = container.read(archiveProvider.notifier);
      expect(
        await controller.save(
          sample(original.path, ScreenshotIntent.task, 'Reminder set'),
        ),
        isFalse,
      );
      final failed = container.read(archiveProvider).items.single;
      expect(failed.disposition, 'Reminder set');
      expect(container.read(archiveProvider).error, isNotNull);
      repo.fail = false;
      await controller.retry();
      expect(container.read(archiveProvider).error, isNull);
      expect(repo.records.keys.single, failed.archiveId);
      expect(repo.records.values.single.notificationId, 9123);
      container.dispose();
    },
  );

  test(
    'quota survives store recreation and entitlement safety stays centralized',
    () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesAnalysisQuotaStore().write(9);
      expect(await SharedPreferencesAnalysisQuotaStore().read(), 9);
      expect(freeAnalysisLimit, 10);
      expect(proEntitlementId, 'screenshot_zero_pro');
      expect(revenueCatKeyAllowed('test_example', debug: true), isTrue);
      expect(revenueCatKeyAllowed('test_example', debug: false), isFalse);
      expect(revenueCatKeyAllowed('', debug: false), isFalse);
      expect(revenueCatKeyAllowed('goog_example', debug: false), isTrue);
    },
  );
}
