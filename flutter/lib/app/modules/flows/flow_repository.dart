import '/app/network/http.dart';

/// 账单接口封装，对齐后端 MoneyFlowController：
/// - 列表 GET /money-flows?page=&size=&sort= + 过滤条件 → 分页 PageResponse
/// - 统计 GET /money-flows/statistics（同一套过滤条件，忽略 type）→ 支出/收入/结余
/// - 新增 POST /money-flows、更新 PATCH /money-flows/{id}、删除 DELETE /money-flows/{id}
///
/// 注意：后端没有 GET /money-flows/{id}（没有单条查询），详情页直接用列表行数据；
/// 也没有 /confirm 端点，确认状态只能通过 PATCH 全量更新修改。
/// 账单附件（原 balance-flows/{id}/files）在新后端不存在，相关接口已移除。
class FlowRepository {

  static Future<bool> create(Map<String, dynamic> form) async {
    return (await Http.post('money-flows', data: form))['success'];
  }

  static Future<bool> update(int id, Map<String, dynamic> form) async {
    return (await Http.patch('money-flows/$id', data: form))['success'];
  }

  static Future<bool> delete(int id) async {
    return (await Http.delete('money-flows/$id'))['success'];
  }

}
