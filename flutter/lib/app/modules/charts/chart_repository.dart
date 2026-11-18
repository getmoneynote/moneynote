import '/app/network/http.dart';

/// 图表数据源，对齐后端新契约（旧的 reports/* 三个端点已全部下线）：
/// - 支出/收入分类环形图：GET /money-flows/category-statistics（type 必填 1=支出 2=收入）
/// - 资产/负债构成环形图：GET /accounts/balanceDistribution（无参数）
///
/// 两个端点下发的金额都是「本位币最小单位」，并附带 currencySymbol / decimalPlaces
/// （分类统计里是 currencyDecimalPlaces），前端按该精度换算展示，不做二次折算。
class ChartRepository {

  /// 分类统计：与流水列表同一套过滤条件（忽略分页/排序），按根分类汇总
  static Future<Map<String, dynamic>> categoryStatistics(Map<String, dynamic> params) async {
    return (await Http.get('money-flows/category-statistics', params: params))['data'];
  }

  /// 资产/负债构成：只统计 include=true 且余额非 0 的账户，按金额降序
  static Future<Map<String, dynamic>> balanceDistribution() async {
    return (await Http.get('accounts/balanceDistribution'))['data'];
  }

}
