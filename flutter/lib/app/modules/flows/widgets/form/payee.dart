import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/flow_form_controller.dart';
import '/app/modules/common/select/select_option.dart';
import '../../../common/select/select_controller.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_select.dart';

class Payee extends StatelessWidget {

  final FlowFormController controller;

  const Payee({
    super.key,
    required this.controller
  });

  @override
  Widget build(BuildContext context) {
    return MySelect(
      label: LocaleKeys.flow_payee.tr,
      value: controller.form['payee'],
      onFocus: () {
        // 交易对象是账本级资源：payees 只有分页列表接口，按所选账本拉取
        Get.find<SelectController>().loadPaged('payees', params: {
          if (controller.form['book']?['value'] != null) 'bookId': controller.form['book']['value'],
        });
        Get.to(() => SelectOption(
          title: LocaleKeys.flow_payee.tr,
          value: controller.form['payee'],
          onSelect: (value) {
            Get.find<FlowFormController>().changePayee(value);
            Get.back();
          },
        ));
      },
    );
  }

}
