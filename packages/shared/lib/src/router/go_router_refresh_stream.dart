import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts any [Stream] into a [Listenable] so `go_router`'s
/// `refreshListenable` re-evaluates `redirect` whenever auth state changes
/// (§17). This is go_router's own documented cookbook pattern — it isn't
/// exported by the package itself, so it's a few lines here instead of an
/// extra dependency.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
