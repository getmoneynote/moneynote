import '../../network/http.dart';

/// 分页数据：与后端 PageResponse.PageData 对应（current 从 1 开始）
class PageData {

  final List<Map<String, dynamic>> content;
  final int current;
  final int pageSize;
  final int total;

  const PageData({
    this.content = const [],
    this.current = 1,
    this.pageSize = 0,
    this.total = 0,
  });

  /// 是否还有下一页（已加载条数小于总数）
  bool get hasMore => content.length < total;

}

class BaseRepository {

  /// 后端分页接口统一返回 { content, current, pageSize, total }；
  /// 兼容旧的非分页数组响应，避免其它未改造模块直接抛类型错误
  static List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    if (data is Map && data['content'] is List) {
      return List<Map<String, dynamic>>.from(data['content']);
    }
    return [];
  }

  static PageData _asPage(dynamic data) {
    if (data is Map && data['content'] is List) {
      return PageData(
        content: List<Map<String, dynamic>>.from(data['content']),
        current: data['current'] ?? 1,
        pageSize: data['pageSize'] ?? 0,
        total: data['total'] ?? 0,
      );
    }
    final List<Map<String, dynamic>> list = _asList(data);
    return PageData(content: list, current: 1, pageSize: list.length, total: list.length);
  }

  static Future<List<Map<String, dynamic>>> query(String prefix, Map<String, dynamic> query) async {
    return _asList((await Http.get(prefix, params: {
      ...query,
    }))['data']);
  }

  static Future<List<Map<String, dynamic>>> query1(String prefix, Map<String, dynamic> query) async {
    return _asList((await Http.get(prefix, params: {
      ...query,
      ...{
        'enable': true,
      }
    }))['data']);
  }

  /// 分页查询：page 从 0 开始、size 为每页条数（后端 Spring Pageable 契约）
  static Future<PageData> queryPage(String prefix, Map<String, dynamic> query) async {
    return _asPage((await Http.get(prefix, params: {
      ...query,
    }))['data']);
  }

  static Future<bool> toggle(String prefix, int id) async {
    return (await Http.patch('$prefix/$id/toggle'))['success'];
  }

  static Future<bool> delete(String prefix, int id) async {
    return (await Http.delete('$prefix/$id'))['success'];
  }

  static Future<Map<String, dynamic>> get(String prefix, int id) async {
    return (await Http.get('$prefix/$id'))['data'];
  }

  /// 取原始 data：统计/概览类接口返回对象而非列表或分页时使用
  static Future<Map<String, dynamic>> data(String uri, {Map<String, dynamic>? params}) async {
    final dynamic result = (await Http.get(uri, params: params))['data'];
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  /// 下拉选项接口（后端统一为 GET {prefix}/options）
  static Future<List<Map<String, dynamic>>> options(String prefix, {Map<String, dynamic>? params}) async {
    return _asList((await Http.get('$prefix/options', params: params))['data']);
  }

  static Future<List<Map<String, dynamic>>> queryAll(String prefix, {Map<String, dynamic>? params}) async {
    return _asList((await Http.get('$prefix/all', params: params))['data']);
  }

  static Future<bool> add(String prefix, Map<String, dynamic> form) async {
    return (await Http.post(prefix, data: form))['success'];
  }

  /// 局部更新：后端统一使用 PATCH（partial update 语义）
  static Future<bool> update(String prefix, int id, Map<String, dynamic> form) async {
    return (await Http.patch('$prefix/$id', data: form))['success'];
  }

  static Future<Map<String, dynamic>> update2(String prefix, int id, Map<String, dynamic> form) async {
    return (await Http.patch('$prefix/$id', data: form));
  }

  static Future<bool> action(String uri) async {
    return (await Http.patch(uri))['success'];
  }

}
