/// Hand-rolled replacement for `dartz`'s `Either` (see ADR-001 in
/// ARCHITECTURE.md) — Dart 3 sealed classes + pattern matching give the
/// same exhaustiveness guarantee with zero extra dependency.
sealed class Result<F, S> {
  const Result();
}

final class Ok<F, S> extends Result<F, S> {
  final S value;
  const Ok(this.value);
}

final class Err<F, S> extends Result<F, S> {
  final F failure;
  const Err(this.failure);
}

extension ResultX<F, S> on Result<F, S> {
  T fold<T>(T Function(F failure) onError, T Function(S value) onSuccess) =>
      switch (this) {
        Ok(value: final v) => onSuccess(v),
        Err(failure: final f) => onError(f),
      };

  bool get isOk => this is Ok<F, S>;
  bool get isErr => this is Err<F, S>;
}
