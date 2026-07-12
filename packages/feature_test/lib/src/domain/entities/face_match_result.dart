import 'package:freezed_annotation/freezed_annotation.dart';

part 'face_match_result.freezed.dart';

/// No client-side confidence threshold — confirmed by reading the old
/// app's two face-match implementations in full (MIGRATION_LOG.md's
/// write-path audit): `matched`/`notMatched` comes straight from the
/// server's own `match` boolean; `confidence` is carried through for
/// display only, never compared against a threshold locally.
enum FaceMatchStatus { unknown, matched, notMatched, error }

@freezed
abstract class FaceMatchResult with _$FaceMatchResult {
  const factory FaceMatchResult({
    required FaceMatchStatus status,
    double? confidence,
  }) = _FaceMatchResult;
}
