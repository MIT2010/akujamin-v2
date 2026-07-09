/// `mobile < 600 < tablet < 1024 < desktop` (§16). No responsive-framework
/// dependency — this is the entire rule set, deliberately small enough that
/// every dev can read all of it in one sitting.
class Breakpoints {
  const Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
}
