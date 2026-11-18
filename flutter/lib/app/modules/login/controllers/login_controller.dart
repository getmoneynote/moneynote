import 'package:flutter/material.dart';
import 'package:formz/formz.dart';
import 'package:get/get.dart';
import 'package:moneynote/generated/locales.g.dart';
import '../../../core/utils/message.dart';
import '/app/core/utils/utils.dart';
import '/app/modules/login/controllers/auth_controller.dart';
import '../data/login_repository.dart';
import '/app/core/commons/form/not_empty_formz.dart';
import '/app/core/base/base_controller.dart';
import '/app/core/values/app_values.dart';

class LoginController extends BaseController {

  bool valid = false;
  /// 登录请求进行中：置灰按钮，避免重复提交和 loading 叠加
  bool logging = false;
  NotEmptyFormz usernameFormz = const NotEmptyFormz.pure();
  NotEmptyFormz passwordFormz = const NotEmptyFormz.pure();
  NotEmptyFormz apiFormz = const NotEmptyFormz.pure();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController apiController = TextEditingController();

  AuthController authController = Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    // 调试包预填默认账号密码，release 包留空（开关见 AppValues.prefillLogin）
    if (AppValues.prefillLogin) {
      usernameController.text = AppValues.debugUsername;
      usernameFormz = NotEmptyFormz.dirty(value: AppValues.debugUsername);
      passwordController.text = AppValues.debugPassword;
      passwordFormz = NotEmptyFormz.dirty(value: AppValues.debugPassword);
    }
    final String api = AppValues.apiUrl.isNotEmpty
        ? AppValues.apiUrl
        : (AppValues.prefillLogin ? AppValues.debugApiUrl : '');
    if (api.isNotEmpty) {
      apiController.text = api;
      apiFormz = NotEmptyFormz.dirty(value: api);
    }
    valid = Formz.validate([usernameFormz, passwordFormz, apiFormz]);
  }

  void usernameChanged(String username) {
    usernameFormz = NotEmptyFormz.dirty(value: username);
    valid = Formz.validate([usernameFormz, passwordFormz, apiFormz]);
    update();
  }

  void passwordChanged(String password) {
    passwordFormz = NotEmptyFormz.dirty(value: password);
    valid = Formz.validate([usernameFormz, passwordFormz, apiFormz]);
    update();
  }

  void apiChanged(String api) {
    apiFormz = NotEmptyFormz.dirty(value: api);
    valid = Formz.validate([usernameFormz, passwordFormz, apiFormz]);
    AppValues.apiUrl = apiFormz.value;
    update();
  }

  void login() async {
    // logging 用于防重复点击：连点会叠加多个 loading，也会发出多次登录请求
    if (!valid || logging) return;
    logging = true;
    update();
    try {
      Message.showLoading(msg: LocaleKeys.user_logging.tr);
      String token = await LoginRepository.logIn(username: usernameFormz.value, password: passwordFormz.value);
      // 等 initState 拉完、status 变成 authenticated 之后再收尾
      await authController.onLoggedIn(token, apiFormz.value);
      reloadState();
    } catch (_) {
      // 失败提示由全局异常拦截器统一处理
      _.printError();
    } finally {
      // 关键：无论成功还是异常都必须关掉 loading，否则会一直挂在屏幕上
      logging = false;
      Message.disLoading();
      if (!isClosed) update();
    }
  }

}