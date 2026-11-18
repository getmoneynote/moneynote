import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../common/select/tree_select_option.dart';
import '../../controllers/flow_form_controller.dart';
import '../../../common/select/select_controller.dart';
import '/generated/locales.g.dart';
import '/app/core/components/form/my_select.dart';

class FormTag extends StatelessWidget {

  final FlowFormController controller;

  const FormTag({
    super.key,
    required this.controller
  });

  @override
  Widget build(BuildContext context) {
    return MySelect(
      multiple: true,
      label: LocaleKeys.flow_tag.tr,
      value: controller.form['tags'],
      onFocus: () {
        // 标签是扁平资源，只有分页列表接口；树控件对无 children 的节点等价于多选列表
        Get.find<SelectController>().loadPaged('tags', params: {
          if (controller.form['book']?['value'] != null) 'bookId': controller.form['book']['value'],
        });
        Get.to(() => TreeSelectOption(
          title: LocaleKeys.flow_tag.tr,
          values: controller.form['tags'],
          onSelect: (values) {
            Get.find<FlowFormController>().changeTags(values);
            Get.back();
          },
        ));
      },
    );
  }

}
