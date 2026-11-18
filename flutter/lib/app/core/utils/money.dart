import 'dart:math' as math;

/// 金额换算工具
///
/// 后端金额一律以「最小货币单位」的整数存储（人民币是分，日元是円），
/// 展示前需要除以 10^decimalPlaces。与 web-pc `src/utils/money.js` 口径一致：
/// - 最小单位金额必须能整除得到合法小数，缺失精度时不做默认兜底（避免零小数位币种被算错 100 倍）
class Money {

  const Money._();

  /// 最小单位 → 展示用小数（如 1050, 2 → 10.5）；输入为空返回 null
  static double? minorToDisplay(dynamic minor, int decimalPlaces) {
    if (minor == null) return null;
    final num? value = num.tryParse(minor.toString());
    if (value == null) return null;
    return value / math.pow(10, decimalPlaces);
  }

  /// 展示用小数 → 最小单位整数（如 10.5, 2 → 1050）；输入为空或非法返回 null
  static int? displayToMinor(dynamic display, int decimalPlaces) {
    if (display == null) return null;
    final String text = display.toString().trim();
    if (text.isEmpty) return null;
    final double? value = double.tryParse(text);
    if (value == null) return null;
    return (value * math.pow(10, decimalPlaces)).round();
  }

  /// 最小单位 → 去掉末尾多余零的字符串（不保留 0 位之外的小数尾部）
  static String formatAmountDisplay(dynamic minor, int decimalPlaces) {
    final double? value = minorToDisplay(minor, decimalPlaces);
    if (value == null) return '';
    String text = value.toStringAsFixed(decimalPlaces > 0 ? decimalPlaces : 0);
    if (text.contains('.')) {
      text = text.replaceAll(RegExp(r'0+$'), '');
      text = text.replaceAll(RegExp(r'\.$'), '');
    }
    return text;
  }

  /// 最小单位 → 带币种符号的展示串（如 ¥10.5）；金额为空时返回空串
  static String formatMoney(dynamic minor, int decimalPlaces, String? symbol) {
    final String text = formatAmountDisplay(minor, decimalPlaces);
    if (text.isEmpty) return '';
    return '${symbol ?? ''}$text';
  }

}
