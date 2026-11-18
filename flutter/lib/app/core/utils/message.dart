import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:moneynote/generated/locales.g.dart';

class Message {

  /// loading 是否仍由本类持有。
  /// showSuccess / showError 会接管同一个 EasyLoading 浮层，此时把 _loading 置 false，
  /// 后续 finally 里的 disLoading() 就不会顺手把提示框关掉（否则错误提示一闪而过）。
  static bool _loading = false;

  static success(String msg) {
    _loading = false;
    EasyLoading.showSuccess(msg, duration: const Duration(seconds: 2));
  }

  static error(String msg) {
    _loading = false;
    EasyLoading.showError(msg, duration: const Duration(seconds: 2));
  }

  static void showLoading({String? msg}) {
    _loading = true;
    EasyLoading.show(
      status: msg ?? LocaleKeys.common_loading.tr,
      maskType: EasyLoadingMaskType.black,
      dismissOnTap: false,
    );
  }

  static void disLoading() {
    // 已经有 success/error 接管浮层时不要抢着关，否则 2 秒提示会被立即打断
    if (!_loading) return;
    _loading = false;
    EasyLoading.dismiss();
  }

  /// 包住一次异步请求：进来先显示 loading，成功或异常都保证关掉
  static Future<T> withLoading<T>(Future<T> Function() action, {String? msg}) async {
    showLoading(msg: msg);
    try {
      return await action();
    } finally {
      disLoading();
    }
  }

}
