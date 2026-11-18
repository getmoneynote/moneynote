import '/app/core/base/base_controller.dart';
import '/app/core/base/base_repository.dart';
import '/app/core/base/enums.dart';
import '/app/network/http.dart';

class SelectController extends BaseController {

  LoadDataStatus status = LoadDataStatus.initial;
  List<dynamic> options = [];

  void load(String prefix, {Map<String, dynamic>? params}) async {
    try {
      status = LoadDataStatus.progress;
      options = [];
      update();
      options = await BaseRepository.queryAll(prefix, params: params);
      if (options.isEmpty) {
        status = LoadDataStatus.empty;
      } else {
        status = LoadDataStatus.success;
      }
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

  /// 下拉字典走 {prefix}/options（后端新版统一契约，返回 { value, label, ... }）
  void loadOptions(String prefix, {Map<String, dynamic>? params}) async {
    try {
      status = LoadDataStatus.progress;
      options = [];
      update();
      options = await BaseRepository.options(prefix, params: params);
      if (options.isEmpty) {
        status = LoadDataStatus.empty;
      } else {
        status = LoadDataStatus.success;
      }
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

  /// 分页列表接口 → 下拉选项。books / payees / tags 等只有列表（GET {prefix}?page=&size=），
  /// 没有 /options，这里把 { id, name, ... } 映射成下拉需要的 { value, label, ... }，
  /// 其余字段原样保留（如 books 的 currencyId、tags 的 canXxx）。
  void loadPaged(String prefix, {Map<String, dynamic>? params, String labelField = 'name', int size = 1000}) async {
    try {
      status = LoadDataStatus.progress;
      options = [];
      update();
      final List<Map<String, dynamic>> list = await BaseRepository.query(prefix, {
        ...?params,
        'page': 0,
        'size': size,
      });
      options = list.map((e) {
        final Map<String, dynamic> option = Map<String, dynamic>.from(e);
        option['value'] = e['id'];
        option['label'] = e[labelField] ?? '';
        return option;
      }).toList();
      status = options.isEmpty ? LoadDataStatus.empty : LoadDataStatus.success;
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

  /// 分类树（GET categories/tree?type=&bookId=）→ 多选树需要的 { value, label, children }
  void loadCategoryTree({required int type, int? bookId}) async {
    try {
      status = LoadDataStatus.progress;
      options = [];
      update();
      final dynamic data = (await Http.get('categories/tree', params: {
        'type': type,
        if (bookId != null) 'bookId': bookId,
      }))['data'];
      options = (data as List? ?? []).map(_toTreeOption).toList();
      status = options.isEmpty ? LoadDataStatus.empty : LoadDataStatus.success;
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

  Map<String, dynamic> _toTreeOption(dynamic node) {
    return {
      'value': node['id'],
      'label': node['name'],
      'children': (node['children'] as List? ?? []).map(_toTreeOption).toList(),
    };
  }

  /// 分类树拍平成单选列表（账单表单的「分类」只能选一个，树多选不适用）。
  /// 层级用全角空格缩进表达，避免叶子/父级看着平铺一团。
  void loadCategoriesFlat({required int type, int? bookId}) async {
    try {
      status = LoadDataStatus.progress;
      options = [];
      update();
      final dynamic data = (await Http.get('categories/tree', params: {
        'type': type,
        if (bookId != null) 'bookId': bookId,
      }))['data'];
      final List<dynamic> flat = [];
      void walk(List nodes, int depth) {
        for (final dynamic node in nodes) {
          flat.add({
            'value': node['id'],
            'label': '${'　' * depth}${node['name']}',
          });
          walk(node['children'] as List? ?? [], depth + 1);
        }
      }

      walk(data as List? ?? [], 0);
      options = flat;
      status = options.isEmpty ? LoadDataStatus.empty : LoadDataStatus.success;
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

  void loadStatic(values) {
    options = values;
    if (options.isEmpty) {
      status = LoadDataStatus.empty;
    } else {
      status = LoadDataStatus.success;
    }
    update();
  }

  void clear() {
    status = LoadDataStatus.empty;
    options = [];
    update();
  }

}
