import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/flow_form_controller.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_form_text.dart';

class Amount extends StatelessWidget {

  final FlowFormController controller;

  const Amount({
    super.key,
    required this.controller
  });

  @override
  Widget build(BuildContext context) {
    final String amountLabel = controller.amountCode.isEmpty
        ? LocaleKeys.flow_amount.tr
        : '${LocaleKeys.flow_amount.tr}(${controller.amountCode})';
    return Column(
      children: [
        MyFormText(
          required: true,
          label: amountLabel,
          value: controller.form['amount'],
          onChange: (value) {
            Get.find<FlowFormController>().changeAmount(value);
          },
        ),
        // 账户币种与目标币种不一致时才需要折算金额（后端此时强校验必填）
        if (controller.needConvert)
          MyFormText(
            required: true,
            label: LocaleKeys.account_detailLabelConvert.trParams({'code': controller.convertCode}),
            value: controller.form['convertedAmount'],
            onChange: (value) {
              Get.find<FlowFormController>().changeConvertedAmount(value);
            },
          ),
      ],
    );
  }

}
