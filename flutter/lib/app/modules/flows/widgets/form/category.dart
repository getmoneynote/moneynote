import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/flow_form_controller.dart';
import '/app/modules/common/select/select_option.dart';
import '../../../common/select/select_controller.dart';
import '/app/core/utils/utils.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_select.dart';

class Category extends StatelessWidget {

  final FlowFormController controller;

  const Category({
    super.key,
    required this.controller
  });

  @override
  Widget build(BuildContext context) {
    return MySelect(
      required: true,
      // 后端一条流水只有一个分类（旧版多分类拆金额已不存在），这里用拍平的树做单选
      label: LocaleKeys.flow_category.tr,
      value: controller.form['category'],
      onFocus: () {
        Get.find<SelectController>().loadCategoriesFlat(
          type: flowTypeToCode(controller.type),
          bookId: controller.form['book']?['value'],
        );
        Get.to(() => SelectOption(
          title: LocaleKeys.flow_category.tr,
          value: controller.form['category'],
          onSelect: (value) {
            Get.find<FlowFormController>().changeCategory(value);
            Get.back();
          },
        ));
      },
    );
  }

}
