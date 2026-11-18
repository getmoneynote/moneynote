import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/flow_form_controller.dart';
import '/app/modules/common/select/select_option.dart';
import '../../../common/select/select_controller.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_select.dart';

class ToAccount extends StatelessWidget {

  final FlowFormController controller;

  const ToAccount({
    super.key,
    required this.controller
  });

  @override
  Widget build(BuildContext context) {
    return MySelect(
      required: true,
      label: LocaleKeys.flow_to.tr,
      value: controller.form['to'],
      onFocus: () {
        // 新增转账按「可转入」过滤；编辑/复制用全量，避免原账户已被关掉开关后选不回来
        Get.find<SelectController>().loadOptions(
          'accounts',
          params: controller.action == 1 ? <String, dynamic>{ 'canTransferTo': true } : <String, dynamic>{ },
        );
        Get.to(() => SelectOption(
          title: LocaleKeys.menu_account.tr,
          value: controller.form['to'],
          onSelect: (value) {
            Get.find<FlowFormController>().changeToAccount(value);
            Get.back();
          },
        ));
      },
    );
  }

}
