import '/app/modules/accounts/data/account_repository.dart';
import '/app/core/base/enums.dart';
import '/app/core/base/base_controller.dart';
import '/app/core/utils/money.dart';

/// 账户概览（我的页面）：走后端 /accounts/netWorth（旧 /accounts/overview 已下线）
class AccountOverviewController extends BaseController {

  LoadDataStatus status = LoadDataStatus.initial;

  /// [总资产, 总负债, 净资产]，已换算为币种主单位金额
  List<num> data = [];
  String currencySymbol = '';
  int decimalPlaces = 2;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() async {
    try {
      status = LoadDataStatus.progress;
      update();
      final Map<String, dynamic> summary = await AccountRepository.netWorth();
      decimalPlaces = summary['decimalPlaces'] ?? 2;
      currencySymbol = summary['currencySymbol'] ?? '';
      data = [
        Money.minorToDisplay(summary['totalAssets'], decimalPlaces) ?? 0,
        Money.minorToDisplay(summary['totalLiabilities'], decimalPlaces) ?? 0,
        Money.minorToDisplay(summary['netWorth'], decimalPlaces) ?? 0,
      ];
      status = LoadDataStatus.success;
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

}
