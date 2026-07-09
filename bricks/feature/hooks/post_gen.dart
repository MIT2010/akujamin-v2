import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart';

/// Adds the freshly generated package to the root pubspec.yaml `workspace:`
/// list — §14's "melos.yaml entry auto-added", updated for Dart pub
/// workspaces where that list lives in the root pubspec, not melos.yaml.
///
/// Structure per the official mason scaffold (`mason new --hooks`): a
/// top-level `run(HookContext)` in hooks/post_gen.dart, with
/// hooks/pubspec.yaml depending on `mason`.
Future<void> run(HookContext context) async {
  // Same conversion the templates use ({{feature_name.snakeCase()}}), via
  // the StringCaseExtensions that package:mason/mason.dart exports — so the
  // hook and the generated folder name can't disagree about casing.
  final featureName = (context.vars['feature_name'] as String).snakeCase;
  final workspaceEntry = 'packages/feature_$featureName';

  final rootPubspec = _findWorkspaceRootPubspec(Directory.current);
  if (rootPubspec == null) {
    context.logger.err(
      'Root pubspec.yaml ber-`workspace:` tidak ditemukan di atas '
      '${Directory.current.path} — tambahkan "  - $workspaceEntry" ke list '
      '`workspace:` secara manual.',
    );
    return;
  }

  final content = rootPubspec.readAsStringSync();
  final lineEnding = content.contains('\r\n') ? '\r\n' : '\n';
  final lines = const LineSplitter().convert(content);

  if (lines.any((line) => line.trim() == '- $workspaceEntry')) {
    context.logger.info('$workspaceEntry sudah terdaftar di workspace.');
  } else {
    final workspaceIndex = lines.indexWhere(
      (line) => line.trimRight() == 'workspace:',
    );
    if (workspaceIndex == -1) {
      context.logger.err(
        'Key `workspace:` tidak ditemukan di ${rootPubspec.path} — '
        'tambahkan "  - $workspaceEntry" secara manual.',
      );
      return;
    }

    // Insert right after the last existing `  - packages/...` entry so
    // ordering and everything else in the file stays untouched.
    var insertIndex = workspaceIndex + 1;
    while (insertIndex < lines.length &&
        lines[insertIndex].trimLeft().startsWith('- ')) {
      insertIndex++;
    }
    lines.insert(insertIndex, '  - $workspaceEntry');
    rootPubspec.writeAsStringSync(lines.join(lineEnding) + lineEnding);
    context.logger.success(
      '$workspaceEntry ditambahkan ke `workspace:` di ${rootPubspec.path}.',
    );
  }

  context.logger.info(
    'Package ditambahkan ke workspace. Jalankan `fvm flutter pub get` lalu '
    '`melos run gen` sebelum pakai.',
  );
  context.logger.info(
    'Wiring manual yang tersisa: dependency + route di apps/mobile, dan '
    'Feature${featureName.pascalCase}PackageModule di injection.dart '
    '(lihat bricks/feature/README.md).',
  );
}

/// Walks upward from [start] until it finds a pubspec.yaml containing a
/// top-level `workspace:` key — more robust than assuming the hook's
/// working directory is the repo root, since mason runs hooks relative to
/// wherever `mason make -o <dir>` pointed.
File? _findWorkspaceRootPubspec(Directory start) {
  var dir = start.absolute;
  while (true) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (pubspec.existsSync()) {
      final hasWorkspaceKey = const LineSplitter()
          .convert(pubspec.readAsStringSync())
          .any((line) => line.trimRight() == 'workspace:');
      if (hasWorkspaceKey) return pubspec;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}
