import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/app/modules/flows/controllers/flow_form_controller.dart';
import '/app/modules/flows/flow_form_page.dart';
import '/app/core/utils/money.dart';
import '/app/core/utils/utils.dart';
import '../../core/components/detail_item.dart';
import '/app/core/components/dialog_confirm.dart';
import '/generated/locales.g.dart';
import '/app/core/components/pages/index.dart';
import 'controllers/flow_detail_controller.dart';

class FlowDetailPage extends StatelessWidget {

  const FlowDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(LocaleKeys.flow_detailTitle.tr),
      ),
      body: GetBuilder<FlowDetailController>(builder: (controller) {
        final Map<String, dynamic> item = controller.item;
        final String type = flowCodeToType(item['type']);
        final String typeName = flowTypeToName(type);

        final String accountName = item['accountName'] ?? '';
        final String accountText = type == 'TRANSFER' && (item['toAccountName']?.isNotEmpty ?? false)
            ? '$accountName → ${item['toAccountName']}'
            : accountName;

        final String tagNames = (item['tags'] as List? ?? [])
            .map((e) => e['name']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .join(', ');

        final String amountText = Money.formatMoney(
          item['amount'],
          item['amountCurrencyDecimalPlaces'] ?? 2,
          item['amountCurrencySymbol'],
        );

        return ContentPage(
          child: Column(
            children: [
              DetailItem(
                label: LocaleKeys.book_whichBook.tr,
                value: item['bookName'],
              ),
              DetailItem(
                label: LocaleKeys.flow_type.tr,
                value: typeName,
              ),
              DetailItem(
                label: LocaleKeys.flow_title.tr,
                value: item['title'],
              ),
              DetailItem(
                label: LocaleKeys.flow_createTime.tr,
                value: dateTimeFormat(item['createTime']),
              ),
              DetailItem(
                label: LocaleKeys.flow_account.tr,
                value: accountText,
              ),
              DetailItem(
                label: LocaleKeys.flow_amount.tr,
                value: amountText,
              ),
              if (item['needConvert'] == true)
                DetailItem(
                  label: LocaleKeys.account_detailLabelConvert.trParams({'code': item['convertedCurrencySymbol'] ?? ''}),
                  value: Money.formatAmountDisplay(item['convertedAmount'], item['convertedCurrencyDecimalPlaces'] ?? 2),
                ),
              if (item['categoryName']?.isNotEmpty ?? false)
                DetailItem(
                  label: LocaleKeys.flow_category.tr,
                  value: item['categoryName'],
                ),
              if (tagNames.isNotEmpty)
                DetailItem(
                  label: LocaleKeys.flow_tag.tr,
                  value: tagNames,
                ),
              if (type != 'TRANSFER' && (item['payeeName']?.isNotEmpty ?? false))
                DetailItem(
                  label: LocaleKeys.flow_payee.tr,
                  value: item['payeeName'],
                ),
              DetailItem(
                label: LocaleKeys.flow_confirm.tr,
                value: boolToString(item['confirm'] ?? false),
              ),
              DetailItem(
                label: LocaleKeys.flow_include.tr,
                value: boolToString(item['include'] ?? false),
              ),
              DetailItem(
                label: LocaleKeys.common_notes.tr,
                value: item['notes'],
                crossAlign: CrossAxisAlignment.start,
              ),
              const SizedBox(height: 15),
              ..._actionBar(context, item, type),
            ],
          ),
        );
      }),
    );
  }

  /// 调整余额（type=4）流水由账户模块产生，账户余额无法在这里安全重建，
  /// 因此只保留删除；转账退款 = 反向转账（后端不允许负数转账），也不提供退款入口。
  List<Widget> _actionBar(BuildContext context, Map<String, dynamic> item, String type) {
    final bool editable = type != 'ADJUST';
    final bool canRefund = type == 'EXPENSE' || type == 'INCOME';
    return [
      if (editable) ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openForm(type, 3, item),
            icon: const Icon(Icons.copy, size: 15),
            label: Text(LocaleKeys.common_copy.tr),
          ),
        ),
        if (canRefund) ...[
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openForm(type, 4, item),
              icon: const Icon(Icons.undo, size: 15),
              label: Text(LocaleKeys.flow_refund.tr),
            ),
          ),
        ],
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openForm(type, 2, item),
            icon: const Icon(Icons.edit, size: 15),
            label: Text(LocaleKeys.common_edit.tr),
          ),
        ),
        const SizedBox(height: 5),
      ],
      SizedBox(
        width: double.infinity,
        child: DialogConfirm(
            content: item['confirm'] == true
                ? LocaleKeys.flow_deleteConfirm.tr
                : LocaleKeys.common_deleteDialogTitle.tr,
            child: AbsorbPointer(
              child: ElevatedButton.icon(
                onPressed: () { },
                icon: const Icon(Icons.delete, size: 15),
                label: Text(LocaleKeys.common_delete.tr),
              ),
            ),
            onConfirm: () {
              Get.find<FlowDetailController>().delete();
            }
        ),
      ),
    ];
  }

  void _openForm(String type, int action, Map<String, dynamic> item) {
    Get.put(FlowFormController(type, action, item));
    Get.to(() => const FlowFormPage(), fullscreenDialog: true)?.then(
      (value) => Get.delete<FlowFormController>()
    );
  }

}
