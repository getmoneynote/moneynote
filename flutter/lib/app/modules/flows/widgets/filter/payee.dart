import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_select.dart';
import '../../../common/select/select_controller.dart';
import '../../../common/select/select_option.dart';
import '../../controllers/flows_controller.dart';

class Payee extends StatelessWidget {

  const Payee({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FlowsController>(builder: (controller) {
      return MySelect(
        label: LocaleKeys.flow_payee.tr,
        value: controller.query['payees'],
        allowClear: true,
        onClear: () {
          controller.query['payees'] = null;
          controller.update();
        },
        onFocus: () {
          // payees 只有分页列表接口；交易对象是账本级资源，选了账本按账本过滤
          Get.find<SelectController>().loadPaged('payees', params: {
            if (controller.query['book']?['value'] != null) 'bookId': controller.query['book']['value'],
          });
          Get.to(() => SelectOption(
            title: LocaleKeys.flow_payee.tr,
            value: controller.query['payees'],
            onSelect: (value) {
              controller.query['payees'] = value;
              controller.update();
              Get.back();
            },
          ));
        },
      );
    });
  }

}
