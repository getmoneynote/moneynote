import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../common/select/tree_select_option.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_select.dart';
import '../../../common/select/select_controller.dart';
import '/app/core/utils/utils.dart';
import '../../controllers/flows_controller.dart';

class Category extends StatelessWidget {

  const Category({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FlowsController>(builder: (controller) {
      return MySelect(
        multiple: true,
        label: LocaleKeys.flow_category.tr,
        value: controller.query['categories'],
        allowClear: true,
        onClear: () {
          controller.query['categories'] = null;
          controller.update();
        },
        onFocus: () {
          // 分类树必须带 type（后端 /categories/tree 的 type 是必填）：
          // 只有支出/收入有分类，未选类型时按支出取，避免打开就是空页
          final String type = controller.query['type'] == 'INCOME' ? 'INCOME' : 'EXPENSE';
          Get.find<SelectController>().loadCategoryTree(
            type: flowTypeToCode(type),
            bookId: controller.query['book']?['value'],
          );
          Get.to(() => TreeSelectOption(
            title: LocaleKeys.flow_category.tr,
            values: controller.query['categories'],
            onSelect: (values) {
              controller.query['categories'] = values;
              controller.update();
              Get.back();
            },
          ));
        },
      );
    });
  }

}
