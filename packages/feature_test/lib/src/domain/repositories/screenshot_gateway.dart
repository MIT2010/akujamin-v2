/// Screenshot/screen-recording protection for the live exam — self-contained
/// in `feature_test` (single consumer, `TestPage`; §1 "extract once", same
/// reasoning as the ML Kit wrapper and the proctoring state machine).
///
/// Bare `Future<void>`, not `Result<Failure, void>`: this wraps a
/// fire-and-forget platform toggle (`no_screenshot`'s own API) with no
/// meaningful failure mode a caller could react to differently — same
/// judgment call the old app's `ScreenshotRepository` made.
///
/// **Real fix for permanent finding #8, not a port**: the old app's
/// `disable()`-equivalent call site was commented out in
/// `TestPage.initState()`, so screenshot protection never actually engaged
/// during a live exam despite the cleanup code around it working correctly.
/// `TestPage` here calls [disable] for real.
abstract class ScreenshotGateway {
  Future<void> disable();
  Future<void> enable();
}
