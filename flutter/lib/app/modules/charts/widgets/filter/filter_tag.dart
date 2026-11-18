import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../charts_controller.dart';
import '../../../common/select/tree_select_option.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_select.dart';
import '../../../common/select/select_controller.dart';

class FilterTag extends StatelessWidget {

  const FilterTag({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChartsController>(builder: (controller) {
      return MySelect(
        multiple: true,
        label: LocaleKeys.flow_tag.tr,
        value: controller.query['tags'],
        allowClear: true,
        onClear: () {
          controller.query['tags'] = null;
          controller.update();
        },
        onFocus: () {
          // tags 只有分页列表接口；树控件对扁平标签等价于多选列表。
          // canExpense/canIncome 后端只在为 true 时生效（false 等于不过滤），所以两个都显式传。
          final Map<String, dynamic> params = { };
          if (controller.query['book']?['value'] != null) {
            params['bookId'] = controller.query['book']['value'];
          }
          params['canExpense'] = controller.tabIndex == 0;
          params['canIncome'] = controller.tabIndex == 1;
          Get.find<SelectController>().loadPaged('tags', params: params);
          Get.to(() => TreeSelectOption(
            title: LocaleKeys.flow_tag.tr,
            values: controller.query['tags'],
            onSelect: (values) {
              controller.query['tags'] = values;
              controller.update();
              Get.back();
            },
          ));
        },
      );
    });
  }

}