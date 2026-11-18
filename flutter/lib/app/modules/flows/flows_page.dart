import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '/app/core/components/order_button.dart';
import '/app/modules/flows/flow_filter_page.dart';
import '/app/modules/flows/controllers/flows_controller.dart';
import '/generated/locales.g.dart';
import '/app/core/base/enums.dart';
import '/app/core/components/pages/index.dart';
import '/app/core/utils/money.dart';
import '/app/core/utils/utils.dart';
import 'controllers/flow_detail_controller.dart';
import 'controllers/flow_form_controller.dart';
import 'flow_detail_page.dart';
import 'flow_form_page.dart';

class FlowsPage extends StatelessWidget {

  const FlowsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Get.find<FlowsController>().reload();
            },
            icon: const Icon(Icons.refresh)
        ),
        centerTitle: true,
        title: Text(LocaleKeys.flow_listPageTitle.tr),
        actions: [
          GetBuilder<FlowsController>(builder: (controller) {
            return OrderButton(
              items: {
                'createTime,desc': LocaleKeys.flow_order1.tr,
                'amount,desc': LocaleKeys.flow_order2.tr,
              },
              selected: controller.sort,
              onSelected: (value) {
                Get.find<FlowsController>().changeSort(value);
              },
            );
          }),
          IconButton(
            onPressed: () {
              Get.to(() => const FlowFilterPage(), fullscreenDialog: true);
            },
            icon: const Icon(Icons.search)
          )
        ],
      ),
      body: GetBuilder<FlowsController>(builder: (controller) {
        LoadDataStatus status = controller.status;
        switch (status) {
          case LoadDataStatus.progress:
          case LoadDataStatus.initial:
            return const LoadingPage();
          case LoadDataStatus.success:
            return SmartRefresher(
              enablePullDown: true,
              enablePullUp: true,
              controller: controller.refreshController,
              child: buildContent(context, controller.items),
              onLoading: () async {
                Get.find<FlowsController>().loadMore();
              },
              onRefresh: () async {
                Get.find<FlowsController>().reload();
              },
            );
          case LoadDataStatus.empty:
            return const EmptyPage();
          case LoadDataStatus.failure:
            return const ErrorPage();
        }
      }),
    );
  }

  Widget buildContent(BuildContext context, List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: items.length,
      itemBuilder: (context, index) {
        Map<String, dynamic> item = items.elementAt(index);
        final String type = flowCodeToType(item['type']);
        final String typeName = flowTypeToName(type);
        TextStyle amountStyle = theme.textTheme.titleLarge ?? const TextStyle(fontWeight: FontWeight.w500, fontSize: 20);
        if (type == 'EXPENSE') amountStyle = amountStyle.copyWith(color: Colors.green);
        if (type == 'INCOME') amountStyle = amountStyle.copyWith(color: Colors.red);

        // 原币金额（账户币种，未归属收/支为账本币种）；币种不一致时补一行 ≈ 换算金额
        final String amountText = Money.formatMoney(
          item['amount'],
          item['amountCurrencyDecimalPlaces'] ?? 2,
          item['amountCurrencySymbol'],
        );
        final String convertedText = item['needConvert'] == true
            ? '≈ ${Money.formatMoney(item['convertedAmount'], item['convertedCurrencyDecimalPlaces'] ?? 2, item['convertedCurrencySymbol'])}'
            : '';

        final List<String> tagNames = (item['tags'] as List? ?? [])
            .map((e) => e['name']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();

        final String accountName = (item['accountName'] ?? '').toString();
        final String toAccountName = (item['toAccountName'] ?? '').toString();
        final String accountText = type == 'TRANSFER' && toAccountName.isNotEmpty
            ? '${accountName.isEmpty ? '-' : accountName} → $toAccountName'
            : accountName;

        // title 后端可空：为空时退回类型名，避免列表出现空白行
        final String rowTitle = (item['title'] ?? '').toString().trim();

        final String subtitle = [
          typeName,
          dateTimeFormat(item['createTime']),
          if (accountText.isNotEmpty) accountText,
          ...tagNames,
        ].join(' · ');

        return ListTile(
          dense: false,
          title: Text(
            rowTitle.isEmpty ? typeName : rowTitle,
            style: theme.textTheme.bodyLarge,
          ),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amountText, style: amountStyle),
                  if (convertedText.isNotEmpty)
                    Text(convertedText, style: theme.textTheme.bodySmall),
                ],
              ),
              const Icon(Icons.keyboard_arrow_right)
            ],
          ),
          onTap: () {
            Get.put(FlowDetailController(item));
            Get.to(() => const FlowDetailPage())?.then((value) => Get.delete<FlowDetailController>());
          },
          // 调整余额流水由账户模块产生，复制没有业务意义；其余类型长按复制
          onLongPress: type == 'ADJUST' ? null : () {
            Get.put(FlowFormController(type, 3, item));
            Get.to(() => const FlowFormPage(), fullscreenDialog: true)?.then(
              (value) => Get.delete<FlowFormController>()
            );
          },
        );
      },
      separatorBuilder: (context, index) {
        return const Divider();
      },
    );
  }

}
