import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/generated/locales.g.dart';
import '../../charts_controller.dart';
import '/app/core/components/form/my_select.dart';
import '../../../common/select/select_controller.dart';
import '../../../common/select/select_option.dart';

class Account extends StatelessWidget {

  const Account({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChartsController>(builder: (controller) {
      return MySelect(
        label: LocaleKeys.menu_account.tr,
        value: controller.query['account'],
        allowClear: true,
        onClear: () {
          controller.query['account'] = null;
          controller.update();
        },
        onFocus: () {
          // 账户走 /accounts/options（轻量、不分页）
          Get.find<SelectController>().loadOptions('accounts');
          Get.to(() => SelectOption(
            title: LocaleKeys.menu_account.tr,
            value: controller.query['account'],
            onSelect: (value) {
              controller.query['account'] = value;
              controller.update();
              Get.back();
            },
          ));
        },
      );
    });
  }

}