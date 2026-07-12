import 'package:injectable/injectable.dart';
import 'package:no_screenshot/no_screenshot.dart';

import '../../domain/repositories/screenshot_gateway.dart';

@LazySingleton(as: ScreenshotGateway)
class ScreenshotGatewayImpl implements ScreenshotGateway {
  final NoScreenshot _screenshot = NoScreenshot.instance;

  @override
  Future<void> disable() => _screenshot.screenshotOff();

  @override
  Future<void> enable() => _screenshot.screenshotOn();
}
