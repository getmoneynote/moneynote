import 'package:get/get.dart';
import '../../../core/utils/message.dart';
import '/app/modules/accounts/controllers/accounts_controller.dart';
import '/app/core/base/base_repository.dart';
import '/app/core/base/enums.dart';
import '/app/core/base/base_controller.dart';

/// 账户详情：后端没有 GET /accounts/{id}，详情数据直接来自列表接口的行，
/// 编辑/删除后从 AccountsController 的最新列表里重新取值
class AccountDetailController extends BaseController {

  final int id;
  Map<String, dynamic> item;
  LoadDataStatus status = LoadDataStatus.initial;

  AccountDetailController(this.id, this.item);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() {
    if (Get.isRegistered<AccountsController>()) {
      for (final row in Get.find<AccountsController>().items) {
        if (row['id'] == id) {
          item = row;
          break;
        }
      }
    }
    status = LoadDataStatus.success;
    update();
  }

  void delete() async {
    try {
      Message.showLoading();
      final result = await BaseRepository.delete('accounts', id);
      if (result) {
        Get.back();
        if (Get.isRegistered<AccountsController>()) {
          Get.find<AccountsController>().reload();
        }
      }
    } catch (_) {
      // 失败提示由全局异常拦截器统一处理
    } finally {
      Message.disLoading();
    }
  }

}
