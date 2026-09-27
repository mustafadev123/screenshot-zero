import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';

Future<void> loadTestFonts() async {
  final config = File('.dart_tool/package_config.json');
  final packages =
      (jsonDecode(await config.readAsString())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;
  final flutter = packages.cast<Map<String, dynamic>>().singleWhere(
    (package) => package['name'] == 'flutter',
  );
  final sdk = Directory.fromUri(
    config.absolute.uri.resolve(flutter['rootUri'] as String),
  ).parent.parent;
  final font = File(
    '${sdk.path}/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
  );
  final bytes = await font.readAsBytes();
  for (final family in ['Roboto', 'serif']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await icons.load();
}
