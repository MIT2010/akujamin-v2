import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'certificate_state.freezed.dart';

@freezed
sealed class CertificateState with _$CertificateState {
  const factory CertificateState.initial() = CertificateInitial;
  const factory CertificateState.loading() = CertificateLoading;
  const factory CertificateState.loaded(Uint8List bytes) = CertificateLoaded;
  const factory CertificateState.error(Failure failure) = CertificateError;
}
