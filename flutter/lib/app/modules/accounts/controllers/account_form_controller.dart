import 'package:formz/formz.dart';
import 'package:get/get.dart';
import '/app/core/utils/message.dart';
import '/app/core/utils/money.dart';
import '/app/core/utils/utils.dart';
import '/app/core/base/base_repository.dart';
import '/app/core/commons/form/not_empty_formz.dart';
import '/app/core/commons/form/not_empty_num_formz.dart';
import '../../login/controllers/auth_controller.dart';
import '/app/core/base/base_controller.dart';
import 'account_detail_controller.dart';
import 'accounts_controller.dart';

class AccountFormController extends BaseController {

  bool valid = false;
  Map<String, dynamic> form = { };
  NotEmptyFormz nameFormz = const NotEmptyFormz.pure();
  NotEmptyNumFormz balanceFormz = const NotEmptyNumFormz.pure();

  String type;
  int action;
  Map<String, dynamic> currentRow;

  /// 当前所选币种的小数位数：金额在表单里是「主单位」文本，提交时按此换算成最小单位
  int currencyDecimalPlaces = 2;

  AccountFormController(this.type, this.action, this.currentRow);

  @override
  void onInit() {
    super.onInit();
    reset();
  }

  void reset() {
    valid = action != 1;
    if (action == 2) {
      // 编辑：账户类型与币种后端不允许改，金额只读（余额调整走 adjust 接口）
      type = accountCodeToType(currentRow['type']);
      currencyDecimalPlaces = currentRow['currencyDecimalPlaces'] ?? 2;
      form = { ...currentRow };
      form['balance'] = Money.formatAmountDisplay(currentRow['balance'], currencyDecimalPlaces);
      form['creditLimit'] = Money.formatAmountDisplay(currentRow['creditLimit'], currencyDecimalPlaces);
      nameFormz = NotEmptyFormz.dirty(value: currentRow['name']);
      balanceFormz = NotEmptyNumFormz.dirty(value: form['balance']);
    }
    if (action == 1) {
      form = {};
      form['canExpense'] = true;
      form['canIncome'] = true;
      form['canTransferFrom'] = true;
      form['canTransferTo'] = true;
      form['include'] = true;
      loadDefaultCurrency();
    }
    update();
  }

  /// 新增时默认选中本位币（会话里的 baseCurrencyId），并补齐展示名与精度
  void loadDefaultCurrency() async {
    final dynamic user = Get.find<AuthController>().initState['user'];
    if (user == null) return;
    final dynamic baseCurrencyId = user['baseCurrencyId'];
    if (baseCurrencyId == null) return;
    form['currencyId'] = baseCurrencyId;
    currencyDecimalPlaces = user['baseCurrencyDecimalPlaces'] ?? 2;
    update();
    try {
      final options = await BaseRepository.options('currencies');
      for (final option in options) {
        if (option['value'] == baseCurrencyId) {
          form['currencyName'] = option['label'];
          form['currencySymbol'] = option['symbol'];
          currencyDecimalPlaces = option['decimalPlaces'] ?? currencyDecimalPlaces;
          break;
        }
      }
      update();
    } catch (_) {
      // 币种字典拉取失败不影响表单，用户仍可手动选择币种
    }
  }

  void submit() async {
    if (valid) {
      try {
        Message.showLoading();
        bool result = false;
        switch (action) {
          case 1:
            result = await BaseRepository.add('accounts', buildCreateForm());
            break;
          case 2:
            result = await BaseRepository.update('accounts', currentRow['id'], buildUpdateForm());
            break;
        }
        if (result) {
          Get.back();
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

  /// 新增：后端 AccountCreateForm 全是必填项（除可选项），金额最小单位
  Map<String, dynamic> buildCreateForm() {
    return {
      'name': form['name'],
      'type': accountTypeToCode(type),
      'currencyId': form['currencyId'],
      'balance': Money.displayToMinor(form['balance'], currencyDecimalPlaces),
      'include': form['include'] ?? true,
      'canExpense': form['canExpense'] ?? true,
      'canIncome': form['canIncome'] ?? true,
      'canTransferFrom': form['canTransferFrom'] ?? true,
      'canTransferTo': form['canTransferTo'] ?? true,
      'no': form['no'],
      'creditLimit': Money.displayToMinor(form['creditLimit'], currencyDecimalPlaces),
      'billDay': int.tryParse('${form['billDay'] ?? ''}'),
      'apr': num.tryParse('${form['apr'] ?? ''}'),
      'notes': form['notes'],
    };
  }

  /// 更新：后端 partial update，只提交可改字段（name/flags/额度/账单日/利率/备注），
  /// 不含 type、currencyId、balance（余额只能通过余额调整接口改）
  Map<String, dynamic> buildUpdateForm() {
    return {
      'name': form['name'],
      'include': form['include'],
      'canExpense': form['canExpense'],
      'canIncome': form['canIncome'],
      'canTransferFrom': form['canTransferFrom'],
      'canTransferTo': form['canTransferTo'],
      'no': form['no'],
      'creditLimit': Money.displayToMinor(form['creditLimit'], currencyDecimalPlaces),
      'billDay': int.tryParse('${form['billDay'] ?? ''}'),
      'apr': num.tryParse('${form['apr'] ?? ''}'),
      'notes': form['notes'],
    };
  }

  /// 币种选项来自 /currencies/options，选中后要同时记住 id 与该币种精度
  void changeCurrency(dynamic option) {
    form['currencyId'] = option['value'];
    form['currencyName'] = option['label'];
    form['currencySymbol'] = option['symbol'];
    currencyDecimalPlaces = option['decimalPlaces'] ?? 2;
    update();
    Get.back();
  }

  void changeName(String value) {
    nameFormz = NotEmptyFormz.dirty(value: value);
    valid = Formz.validate([nameFormz, balanceFormz]);
    form['name'] = value;
    update();
  }

  void changeBalance(String value) {
    balanceFormz = NotEmptyNumFormz.dirty(value: value);
    valid = Formz.validate([nameFormz, balanceFormz]);
    form['balance'] = value;
    update();
  }

  void changeType(String value) {
    type = value;
    update();
    if(Get.isBottomSheetOpen ?? false){
      Get.back();
    }
  }

}
