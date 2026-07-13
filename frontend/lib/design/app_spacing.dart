/// 应用统一间距规范
///
/// 统一采用 8pt Grid：
/// - 页面左右 Padding：24
/// - 组件之间：16
/// - 模块之间：32
/// - 列表间距：12
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const double pageHorizontal = 24;
  static const double component = 16;
  static const double module = 32;
  static const double listItemGap = 12;
}
