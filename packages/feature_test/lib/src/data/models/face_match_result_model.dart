import '../../domain/entities/face_match_result.dart';

/// Parses `POST /pertanyaan/face-matchv2`'s response — confirmed against
/// the old app's `camera` feature's `FaceMatchResultModel.fromJson`
/// during the write-path audit (the *only* live implementation; `test`'s
/// own parallel `matchFace` chain was confirmed dead code and is not
/// migrated). `matched` comes straight from `json['match']`; no
/// client-side threshold is applied to `similarity`.
abstract class FaceMatchResultModel {
  static FaceMatchResult fromJson(Map<String, dynamic> json) {
    return FaceMatchResult(
      status: json['match'] == true
          ? FaceMatchStatus.matched
          : FaceMatchStatus.notMatched,
      confidence: (json['similarity'] as num?)?.toDouble(),
    );
  }
}
