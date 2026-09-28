import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_zero/domain/models/imported_image.dart';
import 'package:screenshot_zero/domain/models/screenshot_intent.dart';
import 'package:screenshot_zero/domain/models/screenshot_item.dart';
import 'package:screenshot_zero/features/archive/archive_provider.dart';
import 'package:screenshot_zero/features/archive/data/archive_repository_io.dart';
import 'package:screenshot_zero/features/zero_stack/inbox_provider.dart';

void main() {
  test('skip leaves original bytes and persistent Archive untouched; reimport works', () async {
    final temp = await Directory.systemTemp.createTemp('skip-session-');
    addTearDown(() => temp.delete(recursive: true));
    final original = File('${temp.path}/original.png');
    final bytes = await File('test/fixtures/selected.png').readAsBytes();
    await original.writeAsBytes(bytes);
    final repository = FileArchiveRepository(
      directory: () async => Directory('${temp.path}/support'),
    );
    final container = ProviderContainer(
      overrides: [archiveRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(archiveProvider.notifier).ensureReady();
    ScreenshotItem item(int id) => ScreenshotItem(
      id: id,
      title: 'Screenshot $id',
      intent: ScreenshotIntent.reference,
      subtitle: '',
      metadata: const [],
      importedImage: ImportedImage(path: original.path, name: 'original.png'),
      primaryAction: 'Save reference',
      archiveLabel: 'Saved reference',
    );
    final skipped = item(1);
    final inbox = container.read(inboxProvider.notifier);
    inbox.replaceCollection([skipped, item(2), item(3)]);
    inbox.skip(1);
    expect(container.read(inboxProvider).map((item) => item.id), [2, 3]);
    expect(skipped.processed, isFalse);
    expect(skipped.actionStatus, isNull);
    expect(await repository.load(), isEmpty);
    expect(await inbox.process(2, status: 'Saved reference'), isTrue);
    expect(await inbox.process(3, saveOnly: true), isTrue);
    inbox.skip(2); // Already completed records cannot be dismissed.
    inbox.skip(1); // Repeated stale skips are harmless.
    expect(
      container.read(inboxProvider).every((item) => item.processed),
      isTrue,
    );
    final restored = await repository.load();
    expect(restored.length, 2);
    expect(restored.any((item) => item.id == 1), isFalse);
    expect(
      restored.singleWhere((item) => item.id == 2).disposition,
      'Saved reference',
    );
    expect(
      restored.singleWhere((item) => item.id == 3).disposition,
      'Saved to archive',
    );
    expect(await original.readAsBytes(), bytes);
    inbox.replaceCollection([skipped]);
    expect(container.read(inboxProvider).single, same(skipped));
    expect(await inbox.process(1, saveOnly: true), isTrue);
    expect((await repository.load()).length, 3);
    expect(await original.readAsBytes(), bytes);
  });
}
