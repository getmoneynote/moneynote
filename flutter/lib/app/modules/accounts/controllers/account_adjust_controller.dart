import 'package:get/get.dart';
import 'package:formz/formz.dart';
import '../../../core/utils/message.dart';
import '../../../core/utils/money.dart';
import '/app/modules/accounts/controllers/account_detail_controller.dart';
import '/app/modules/accounts/controllers/accounts_controller.dart';
import '/app/core/commons/form/not_empty_num_formz.dart';
import '/app/core/base/base_controller.dart';
import '../data/account_repository.dart';

/// 余额调整：把账户余额覆盖为目标值，后端写一条 type=4(ADJUST) 流水历史。
/// 后端只有 POST /accounts/{id}/adjust（没有 PUT），且表单必填 balance/include/createTime。
class AccountAdjustController extends BaseController {

  bool valid = false;
  Map<String, dynamic> form = { };
  NotEmptyNumFormz balanceFormz = const NotEmptyNumFormz.pure();

  int action;
  Map<String, dynamic> currentRow;

  /// 账户币种精度：表单里余额是「主单位」文本，提交时换算为最小单位
  int currencyDecimalPlaces = 2;

  AccountAdjustController(this.action, this.currentRow);

  @override
  void onInit() {
    super.onInit();
    currencyDecimalPlaces = currentRow['currencyDecimalPlaces'] ?? 2;
    form['createTime'] = DateTime.now().millisecondsSinceEpoch;
    form['include'] = true;
    if (action == 1) {
      // 目标余额默认回填当前余额（主单位），用户改成目标值即可
      form['balance'] = Money.formatAmountDisplay(currentRow['balance'], currencyDecimalPlaces);
      balanceFormz = NotEmptyNumFormz.dirty(value: form['balance']);
      valid = Formz.validate([balanceFormz]);
    }
  }

  void balanceChanged(String value) {
    balanceFormz = NotEmptyNumFormz.dirty(value: value);
    valid = Formz.validate([balanceFormz]);
    form['balance'] = value;
    update();
  }

  void submit() async {
    if (!valid) return;
    try {
      Message.showLoading();
      final Map<String, dynamic> newForm = {
        'balance': Money.displayToMinor(form['balance'], currencyDecimalPlaces),
        'createTime': form['createTime'],
        'title': form['title'],
        'notes': form['notes'],
        'include': form['include'] ?? true,
      };
      final bool result = await AccountRepository.adjust(currentRow['id'], newForm);
      if (result) {
        Get.back();
        // 余额变了，列表与详情都要刷新
        if (Get.isRegistered<AccountsController>()) {
          await Get.find<AccountsController>().reload();
        }
        if (Get.isRegistered<AccountDetailController>()) {
          Get.find<AccountDetailController>().load();
        }
      }
    } catch (_) {
      // 失败提示由全局异常拦截器统一处理
    } finally {
      Message.disLoading();
    }
  }

}
