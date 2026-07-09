// Run via `melos run doctor` (which is `fvm dart run tool/verify_fvm.dart`).
// Pure Dart + dart:io only — deliberately no shell one-liners (grep/cut/
// $(...)) since this repo also targets Windows (ADR-006). Exit codes:
// 0 = pinned version is genuinely the one active; 1 = anything else.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // tool/verify_fvm.dart -> tool/ -> repo root. More robust than relying
  // on the caller's working directory being the repo root.
  final repoRoot = File.fromUri(Platform.script).parent.parent;
  final fvmrcFile = File('${repoRoot.path}${Platform.pathSeparator}.fvmrc');

  if (!fvmrcFile.existsSync()) {
    stderr.writeln(
      'FVM belum di-setup: file .fvmrc tidak ditemukan di ${repoRoot.path}.\n'
      'Jalankan: fvm use <versi> --pin',
    );
    exit(1);
  }

  final String pinnedVersion;
  try {
    final fvmrc = jsonDecode(fvmrcFile.readAsStringSync());
    final flutterField = (fvmrc as Map<String, dynamic>)['flutter'];
    if (flutterField is! String || flutterField.isEmpty) {
      stderr.writeln(
        'FVM belum di-setup dengan benar: .fvmrc ada tapi field "flutter" '
        'kosong atau bukan versi yang di-pin (isi saat ini: '
        '${jsonEncode(flutterField)}).\n'
        'Jalankan: fvm use <versi> --pin',
      );
      exit(1);
    }
    pinnedVersion = flutterField;
  } on FormatException catch (e) {
    stderr.writeln('.fvmrc bukan JSON yang valid (${fvmrcFile.path}): $e');
    exit(1);
  }

  final ProcessResult result;
  try {
    result = await Process.run(
      'fvm',
      ['flutter', '--version', '--machine'],
      // Needed on Windows to resolve the `fvm.bat` shim from PATH;
      // harmless on macOS/Linux where `fvm` is a plain executable.
      runInShell: true,
    );
  } on ProcessException {
    stderr.writeln(
      'Perintah "fvm" tidak ditemukan di PATH.\n'
      'Install dulu: dart pub global activate fvm\n'
      'Lalu jalankan: fvm use $pinnedVersion --pin',
    );
    exit(1);
  }

  if (result.exitCode != 0) {
    stderr.writeln(
      '"fvm flutter --version --machine" gagal (exit ${result.exitCode}):\n'
      '${result.stderr}',
    );
    exit(1);
  }

  final Map<String, dynamic> versionInfo;
  try {
    // fvm occasionally prints a banner line before the JSON payload; find
    // the first "{" and parse from there instead of assuming stdout is
    // pure JSON.
    final raw = result.stdout.toString();
    final jsonStart = raw.indexOf('{');
    if (jsonStart == -1) throw const FormatException('no JSON object found');
    versionInfo = jsonDecode(raw.substring(jsonStart)) as Map<String, dynamic>;
  } on FormatException catch (e) {
    stderr.writeln(
      'Tidak bisa membaca output "fvm flutter --version --machine": $e\n'
      'Output mentah:\n${result.stdout}',
    );
    exit(1);
  }

  final actualVersion = versionInfo['flutterVersion'] as String?;
  final flutterRoot = versionInfo['flutterRoot'] as String?;

  if (actualVersion == null) {
    stderr.writeln(
      'Output "fvm flutter --version --machine" tidak berisi field '
      '"flutterVersion". Output mentah:\n${result.stdout}',
    );
    exit(1);
  }

  if (actualVersion != pinnedVersion) {
    stderr.writeln(
      'Versi Flutter yang aktif TIDAK cocok dengan .fvmrc!\n'
      '  Pinned (.fvmrc) : $pinnedVersion\n'
      '  Actual (fvm)    : $actualVersion\n'
      '  SDK path        : ${flutterRoot ?? '(tidak diketahui)'}\n\n'
      'Jalankan: fvm use $pinnedVersion --pin',
    );
    exit(1);
  }

  stdout.writeln(
    'FVM OK — versi $actualVersion aktif dan sesuai .fvmrc '
    '(SDK: ${flutterRoot ?? '(tidak diketahui)'})',
  );
  exit(0);
}
