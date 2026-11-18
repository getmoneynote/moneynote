import '../../../network/http.dart';

/// 账户接口封装，对齐后端 AccountController：
/// - 列表 GET /accounts?page=&size=&type=  → 分页 PageData
/// - 汇总 GET /accounts/balanceSummary?type=
/// - 净资产 GET /accounts/netWorth
/// - 新增 POST /accounts、更新 PATCH /accounts/{id}、删除 DELETE /accounts/{id}
/// - 余额调整 POST /accounts/{id}/adjust（无 PUT，也没有 /toggle）
class AccountRepository {

  /// 余额调整：目标余额覆盖，后端写一条 type=4 的流水历史
  static Future<bool> adjust(int id, Map<String, dynamic> form) async {
    return (await Http.post('accounts/$id/adjust', data: form))['success'];
  }

  /// 当前筛选条件（含 tab 的 type）下的余额汇总，金额为本位币最小单位
  static Future<Map<String, dynamic>> balanceSummary({int? type}) async {
    return (await Http.get('accounts/balanceSummary', params: {
      if (type != null) 'type': type,
    }))['data'];
  }

  /// 净资产概览：总资产 / 总负债 / 净资产（只统计 include=true 的账户）
  static Future<Map<String, dynamic>> netWorth() async {
    return (await Http.get('accounts/netWorth'))['data'];
  }

}
