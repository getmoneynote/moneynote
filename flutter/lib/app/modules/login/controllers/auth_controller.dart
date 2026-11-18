import 'package:get/get.dart';
import '/app/network/http.dart';
import '/app/core/utils/api_url.dart';
import '/app/modules/login/data/login_repository.dart';
import '/app/core/utils/token.dart';
import '/app/core/base/base_controller.dart';
import 'login_controller.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthController extends BaseController {

  AuthStatus status = AuthStatus.uninitialized;
  Map<String, dynamic> initState = const { };

  Future<void> onLoggedIn(String token, String api) async {
    await Token.save(token);
    await ApiUrl.save(api);
    // 必须 await：登录页要等会话真正初始化完再关 loading，
    // 否则会出现「loading 已消失但还没进主页 / 又退回登录页」的中间态
    await onAppStarted();
  }

  void onLoggedOut() async {
    try {
      // 让后端作废当前 token；失败也要继续清本地状态，不能让用户卡在已登录态
      await Http.post('logout');
    } catch (_) { }
    await Token.delete();
    status = AuthStatus.unauthenticated;
    initState = const { };
    Get.delete<LoginController>();
    update();
  }

  Future<void> onAppStarted() async {
    final String token = await Token.get();
    final String apiUrl = await ApiUrl.get();
    if (apiUrl.isNotEmpty && token.isNotEmpty) {
      try {
        initState = await LoginRepository.getInitState();
        status = AuthStatus.authenticated;
      } catch (_) {
        status = AuthStatus.unauthenticated;
      }
    } else {
      status = AuthStatus.unauthenticated;
    }
    update();
  }

  /// 重新拉取会话状态。新后端 initState 只返回 { user: {...} }（group 概念已取消）。
  Future<void> refreshInitState() async {
    try {
      initState = await LoginRepository.getInitState();
      status = AuthStatus.authenticated;
      update();
    } catch (_) {
      // 只做一次同步，失败就保留旧副本，不该把用户踢下线
    }
  }

  /// setBaseCurrency 等端点会直接返回变更后的会话 VO（响应即失效通知），
  /// 用它覆盖本地副本即可，不必再请求一次 initState。
  void applyUser(dynamic user) {
    initState = {
      ...initState,
      'user': user,
    };
    update();
  }

  @override
  void onInit() {
    super.onInit();
    onAppStarted();
  }

  dynamic get user => initState['user'];

  /// 本位币小数位：新增账户/金额换算的兜底精度，后端在会话 VO 里补齐
  int get baseCurrencyDecimalPlaces {
    final dynamic value = user?['baseCurrencyDecimalPlaces'];
    if (value is int) return value;
    return int.tryParse('$value') ?? 2;
  }

}