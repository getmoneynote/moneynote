import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/flow_form_controller.dart';
import '/app/modules/common/select/select_option.dart';
import '../../../common/select/select_controller.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_select.dart';

class Account extends StatelessWidget {

  final FlowFormController controller;

  const Account({
    super.key,
    required this.controller
  });

  @override
  Widget build(BuildContext context) {
    return MySelect(
      // 支出/收入可留空（未归属/待核对）；转账的转出账户必填
      required: controller.type == 'TRANSFER',
      label: controller.type == 'TRANSFER'? LocaleKeys.flow_from.tr : LocaleKeys.flow_account.tr,
      value: controller.form['account'],
      onFocus: () {
        // 新增态按流水类型过滤账户用途开关；编辑/复制不过滤，
        // 否则历史流水的账户被关掉开关后就选不回原值了
        Map<String, dynamic> params = { };
        if (controller.action == 1) {
          if (controller.type == 'EXPENSE') {
            params['canExpense'] = true;
          } else if (controller.type == 'INCOME') {
            params['canIncome'] = true;
          } else if (controller.type == 'TRANSFER') {
            params['canTransferFrom'] = true;
          }
        }
        Get.find<SelectController>().loadOptions('accounts', params: params);
        Get.to(() => SelectOption(
          title: LocaleKeys.menu_account.tr,
          value: controller.form['account'],
          onSelect: (value) {
            Get.find<FlowFormController>().changeAccount(value);
            Get.back();
          },
        ));
      },
    );
  }

}
