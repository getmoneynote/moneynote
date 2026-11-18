import 'package:flutter/foundation.dart';

class AppValues {

  static const String appName = 'MoneyNote';
  static const String version = '1.0.44';

  // 调试用默认登录信息：debug 包预填，release 包不预填
  static const String debugUsername = '111';
  static const String debugPassword = '111111';
  static const String debugApiUrl = 'http://10.0.2.2:9096';

  // 登录页是否预填调试信息（开关）
  // 默认跟随编译模式：debug 为 true，profile / release 为 false。
  // 需要临时覆盖时用 --dart-define=PREFILL_LOGIN=true / false
  static const String _prefillLoginEnv = String.fromEnvironment('PREFILL_LOGIN');
  static bool prefillLogin = _prefillLoginEnv.isEmpty
      ? kDebugMode
      : _prefillLoginEnv.toLowerCase() == 'true';

  static String apiUrl = '';

}
