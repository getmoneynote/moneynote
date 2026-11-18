import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/account_form_controller.dart';
import '/app/modules/accounts/controllers/account_adjust_controller.dart';
import '/app/core/components/dialog_confirm.dart';
import '/app/core/components/detail_item.dart';
import '/app/modules/accounts/controllers/account_detail_controller.dart';
import '/app/core/utils/money.dart';
import '/generated/locales.g.dart';
import '/app/core/base/enums.dart';
import '/app/core/components/pages/index.dart';
import '/app/core/utils/message.dart';
import '/app/core/utils/utils.dart';
import 'account_adjust_page.dart';
import 'account_form_page.dart';

class AccountDetailPage extends StatelessWidget {

  const AccountDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(LocaleKeys.account_detailTitle.tr),
      ),
      body: GetBuilder<AccountDetailController>(builder: (controller) {
        LoadDataStatus status = controller.status;
        switch (status) {
          case LoadDataStatus.progress:
          case LoadDataStatus.initial:
            return const LoadingPage();
          case LoadDataStatus.success:
            final item = controller.item;
            final String type = accountCodeToType(item['type']);
            final bool isCredit = type == 'CREDIT';
            final bool isLoan = type == 'DEBT';
            final int decimalPlaces = item['currencyDecimalPlaces'] ?? 2;
            final String symbol = item['currencySymbol'] ?? '';
            return ContentPage(
              child: Column(
                children: [
                  DetailItem(
                    label: LocaleKeys.account_detailLabelTypeName.tr,
                    value: accountTypeToName(type)
                  ),
                  DetailItem(
                    label: LocaleKeys.account_detailLabelName.tr,
                    value: item['name'], space: false
                  ),
                  DetailItem(
                    label: LocaleKeys.account_detailLabelBalance.tr,
                    value: Money.formatMoney(item['balance'], decimalPlaces, symbol),
                    tail: TextButton(
                      child: Text(LocaleKeys.account_detailAdjust.tr),
                      onPressed: () {
                        Get.put(AccountAdjustController(1, controller.item));
                        Get.to(() => const AccountAdjustPage(), fullscreenDialog: true)?.then(
                          (value) => Get.delete<AccountAdjustController>()
                        );
                      }
                    ),
                    space: false,
                  ),
                  DetailItem(
                    label: LocaleKeys.account_detailLabelCurrency.tr,
                    value: item['currencyName']
                  ),
                  // 是否本位币由后端 isBaseCurrency 判定，非本位币才展示折合金额
                  if (item['isBaseCurrency'] == false && item['baseBalance'] != null) ...[
                    DetailItem(
                      label: LocaleKeys.account_detailLabelConvert.trParams({'code': item['baseCurrencySymbol'] ?? ''}),
                      value: Money.formatMoney(item['baseBalance'], item['baseCurrencyDecimalPlaces'] ?? 2, item['baseCurrencySymbol'])
                    ),
                  ],
                  if (isCredit || isLoan) ...[
                    DetailItem(
                      label: LocaleKeys.account_detailLabelCreditLimit.tr,
                      value: Money.formatMoney(item['creditLimit'], decimalPlaces, symbol)
                    ),
                    DetailItem(
                      label: LocaleKeys.account_detailLabelRemainLimit.tr,
                      value: Money.formatMoney(item['remainLimit'], decimalPlaces, symbol)
                    ),
                  ],
                  if (isCredit) ...[
                    DetailItem(
                      label: LocaleKeys.account_detailLabelBillDay.tr,
                      value: item['billDay']?.toString()
                    )
                  ],
                  if (isLoan) ...[
                    DetailItem(
                      label: LocaleKeys.account_detailLabelPayDay.tr,
                      value: item['billDay']?.toString()
                    ),
                    DetailItem(
                      label: LocaleKeys.account_detailLabelApr.tr,
                      value: item['apr']?.toString()
                    )
                  ],
                  DetailItem(
                    label: LocaleKeys.account_detailLabelInclude.tr,
                    value: boolToString(item['include'] == true)
                  ),
                  DetailItem(
                    label: LocaleKeys.account_detailLabelCanExpense.tr,
                    value: boolToString(item['canExpense'] == true)
                  ),
                  DetailItem(
                    label: LocaleKeys.account_detailLabelCanIncome.tr,
                    value: boolToString(item['canIncome'] == true)
                  ),
                  DetailItem(
                    label: LocaleKeys.account_detailLabelCanTransferTo.tr,
                    value: boolToString(item['canTransferTo'] == true)
                  ),
                  DetailItem(
                    label: LocaleKeys.account_detailLabelCanTransferFrom.tr,
                    value: boolToString(item['canTransferFrom'] == true),
                    space: !(item['no'] != null && item['no'].toString().isNotEmpty)
                  ),
                  (item['no'] != null && item['no'].toString().isNotEmpty) ?
                  DetailItem(
                    label: LocaleKeys.account_detailLabelNo.tr,
                    value: item['no'],
                    tail: TextButton(
                      child: Text(LocaleKeys.common_copy.tr),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item['no'])).then((_) => Message.success(LocaleKeys.common_operationSuccess.tr));
                      }
                    ),
                    space: false
                  ) :
                  DetailItem(
                    label: LocaleKeys.account_detailLabelNo.tr,
                    value: item['no']
                  ),
                  DetailItem(
                    label: LocaleKeys.common_notes.tr,
                    value: item['notes'], crossAlign: CrossAxisAlignment.start
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit, size: 15),
                      onPressed: () {
                        Get.put(AccountFormController(type, 2, controller.item));
                        Get.to(() => const AccountFormPage(), fullscreenDialog: true)?.then(
                          (value) => Get.delete<AccountFormController>()
                        );
                      },
                      label: Text(LocaleKeys.common_edit.tr),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: DialogConfirm(
                        child: AbsorbPointer(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.delete, size: 15),
                            onPressed: () { },
                            label: Text(LocaleKeys.common_delete.tr),
                          )
                        ),
                        onConfirm: () {
                          Get.find<AccountDetailController>().delete();
                        }
                    ),
                  )
                ],
              )
            );
          default:
            return const ErrorPage();
        }
      }),
    );
  }

}
