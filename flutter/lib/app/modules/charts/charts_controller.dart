import '/app/core/base/enums.dart';
import '/app/core/base/base_controller.dart';
import '/app/core/utils/money.dart';
import '/app/core/utils/utils.dart';
import 'chart_repository.dart';

/// 图表页：四个 tab 分别是「支出分类 / 收入分类 / 资产构成 / 负债构成」。
///
/// 对齐后端新契约：
/// - 支出/收入：GET /money-flows/category-statistics?type=1|2，与流水列表同一套过滤条件，
///   后端按「根分类」汇总成 { name, amount }；金额为本位币最小单位，
///   精度取 currencyDecimalPlaces、符号取 currencySymbol；
/// - 资产/负债：GET /accounts/balanceDistribution，无参数（固定只统计 include=true 且余额非 0 的账户），
///   金额同样为本位币最小单位 + decimalPlaces。
///
/// 百分比后端不算，这里按占总额比例算好塞进 `percent`，图表与图例都直接读。
class ChartsController extends BaseController {

  LoadDataStatus status = LoadDataStatus.initial;

  /// 图表数据，沿用 syncfusion 的取值字段：[{ x: 名称, y: 展示金额, percent: 占比 }]
  List<Map<String, dynamic>> data = [];

  /// 本位币符号 / 小数位，由后端随响应下发（分类统计与账户分布字段名不同）
  String currencySymbol = '';
  int decimalPlaces = 2;

  /// 过滤条件：与「流水」tab 同名同义，值保持下拉的 { value, label } 结构，请求前在 buildQuery 拍平。
  /// 默认「计入统计」为 true，与流水列表一致，避免不计入统计的流水把图表撑大。
  Map<String, dynamic> query = {
    'include': true,
  };

  int tabIndex = 0;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void tabClick(int index) {
    if (tabIndex == index) return;
    tabIndex = index;
    update();
    reload();
  }

  /// 只有支出/收入两个 tab 支持过滤；资产/负债是账户余额快照，后端端点也没有参数
  bool get canFilter => tabIndex < 2;

  /// 分类统计的 type：1=支出 2=收入
  int get flowTypeCode => tabIndex == 1 ? 2 : 1;

  void reset() {
    query = {
      'include': true,
    };
    update();
  }

  Future<void> reload() async {
    // 请求期间用户可能已经切了 tab，回来发现数据不属于当前 tab 就丢弃
    final int requestTab = tabIndex;
    try {
      status = LoadDataStatus.progress;
      data = [];
      update();

      final Map<String, dynamic> res = canFilter
          ? await ChartRepository.categoryStatistics(buildQuery())
          : await ChartRepository.balanceDistribution();
      if (requestTab != tabIndex) return;

      if (canFilter) {
        currencySymbol = (res['currencySymbol'] ?? '').toString();
        decimalPlaces = _toInt(res['currencyDecimalPlaces'], 2);
        data = _toChartData(res['categories']);
      } else {
        currencySymbol = (res['currencySymbol'] ?? '').toString();
        decimalPlaces = _toInt(res['decimalPlaces'], 2);
        data = _toChartData(requestTab == 2 ? res['assets'] : res['liabilities']);
      }

      status = data.isEmpty ? LoadDataStatus.empty : LoadDataStatus.success;
      update();
    } catch (_) {
      if (requestTab != tabIndex) return;
      status = LoadDataStatus.failure;
      update();
    }
  }

  void queryChanged(Map<String, dynamic> newQuery) {
    query = {
      ...query,
      ...newQuery,
    };
    reload();
  }

  /// 最小单位金额 → 展示金额，并补上占比
  List<Map<String, dynamic>> _toChartData(dynamic items) {
    final List<Map<String, dynamic>> rows = [];
    for (final dynamic item in (items as List? ?? [])) {
      final double? amount = Money.minorToDisplay(item['amount'], decimalPlaces);
      rows.add({
        'x': (item['name'] ?? '').toString(),
        'y': amount ?? 0,
      });
    }
    double total = 0;
    for (final row in rows) {
      total += (row['y'] as num).toDouble();
    }
    for (final row in rows) {
      final double y = (row['y'] as num).toDouble();
      row['percent'] = total == 0 ? 0 : double.parse((y / total * 100).toStringAsFixed(2));
    }
    return rows;
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }

  /// UI 过滤条件 → 后端 MoneyFlowQueryForm（空值不下发）
  Map<String, dynamic> buildQuery() {
    final Map<String, dynamic> params = {
      'type': flowTypeCode,
    };

    final dynamic book = query['book'];
    if (book?['value'] != null) {
      params['bookId'] = book['value'];
    }

    if (!isNullEmpty(query['title'])) {
      params['title'] = query['title'];
    }

    final int? minTime = query['minTime'];
    if (minTime != null) {
      params['minTime'] = minTime;
    }
    final int? maxTime = query['maxTime'];
    if (maxTime != null) {
      // 后端是闭区间：结束日期取当天 23:59:59.999，否则当天的流水会被漏掉
      params['maxTime'] = maxTime + 86399999;
    }

    final dynamic account = query['account'];
    if (account?['value'] != null) {
      params['accountId'] = account['value'];
    }

    final dynamic payee = query['payees'];
    if (payee?['value'] != null) {
      params['payeeIds'] = '${payee['value']}';
    }

    final List<dynamic> categories = query['categories'] ?? [];
    if (categories.isNotEmpty) {
      params['categoryIds'] = categories.map((e) => e['value']).join(',');
    }

    final List<dynamic> tags = query['tags'] ?? [];
    if (tags.isNotEmpty) {
      params['tagIds'] = tags.map((e) => e['value']).join(',');
    }

    if (query['confirm'] != null) {
      params['confirm'] = query['confirm'];
    }
    if (query['include'] != null) {
      params['include'] = query['include'];
    }
    return params;
  }

  // ------------------------------------------------------------ 快捷时间区间

  void _setRange(DateTime start, DateTime end) {
    query['minTime'] = start.millisecondsSinceEpoch;
    query['maxTime'] = end.millisecondsSinceEpoch;
    update();
  }

  /// 近 30 天
  void setTime1() {
    _setRange(DateTime.now().subtract(const Duration(days: 30)), DateTime.now());
  }

  /// 近 12 个月
  void setTime2() {
    _setRange(DateTime.now().subtract(const Duration(days: 365)), DateTime.now());
  }

  /// 本月
  void setTime3() {
    final DateTime now = DateTime.now();
    _setRange(DateTime(now.year, now.month), now);
  }

  /// 本年
  void setTime4() {
    final DateTime now = DateTime.now();
    _setRange(DateTime(now.year), now);
  }

  /// 去年
  void setTime5() {
    final int year = DateTime.now().year - 1;
    _setRange(DateTime(year), DateTime(year, 12, 31, 23, 59, 59, 999));
  }

}
