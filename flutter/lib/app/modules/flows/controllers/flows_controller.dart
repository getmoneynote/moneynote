import 'package:pull_to_refresh/pull_to_refresh.dart';
import '/app/core/base/base_repository.dart';
import '/app/core/values/app_const.dart';
import '/app/core/base/enums.dart';
import '/app/core/base/base_controller.dart';
import '/app/core/utils/utils.dart';

/// 账单列表：对齐后端 MoneyFlowController
/// - 列表 GET /money-flows（Spring 分页：page 从 0、size、sort=字段,方向）
class FlowsController extends BaseController {

  LoadDataStatus status = LoadDataStatus.initial;
  List<Map<String, dynamic>> items = [];
  int total = 0;

  late RefreshController refreshController;

  static const int pageSize = AppConst.defaultPageSize;

  /// 排序：后端 Pageable 的 `字段,方向` 语法
  String sort = 'createTime,desc';

  /// 过滤条件，值保持下拉选项的 {value,label} 结构，请求时在 buildQuery 里拍平。
  /// 默认「计入统计」为 true（与 web-pc 一致）：列表默认不含「不计入统计」的流水，
  /// 用户清空该条件即可查看全部。
  Map<String, dynamic> query = {
    'include': true,
  };

  @override
  void onInit() {
    super.onInit();
    refreshController = RefreshController(initialRefresh: false);
    reload();
  }

  void reset() {
    query = {
      'include': true,
    };
    sort = 'createTime,desc';
    update();
  }

  Future<void> reload() async {
    try {
      status = LoadDataStatus.progress;
      update();
      final PageData pageData = await BaseRepository.queryPage('money-flows', buildQuery(0));
      items = pageData.content;
      total = pageData.total;
      status = items.isEmpty ? LoadDataStatus.empty : LoadDataStatus.success;
      refreshController.refreshCompleted();
      refreshController.loadComplete();
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

  void loadMore() async {
    if (items.length >= total) {
      refreshController.loadNoData();
      return;
    }
    try {
      final PageData pageData = await BaseRepository.queryPage('money-flows', buildQuery(items.length ~/ pageSize));
      if (pageData.content.isNotEmpty) {
        items = List.of(items)..addAll(pageData.content);
        total = pageData.total;
        refreshController.loadComplete();
      } else {
        refreshController.loadNoData();
      }
      update();
    } catch (_) {
      refreshController.loadFailed();
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

  void changeSort(value) {
    sort = value;
    reload();
  }

  @override
  void dispose() {
    super.dispose();
    refreshController.dispose();
  }

  /// UI 过滤条件 → 后端 MoneyFlowQueryForm（空值不下发）
  Map<String, dynamic> buildQuery(int page) {
    final Map<String, dynamic> params = {
      'page': page,
      'size': pageSize,
    };
    if (sort.isNotEmpty) {
      params['sort'] = sort;
    }

    final dynamic book = query['book'];
    if (book?['value'] != null) {
      params['bookId'] = book['value'];
    }

    if (query['type'] != null) {
      params['type'] = flowTypeToCode(query['type']);
    }

    if (!isNullEmpty(query['title'])) {
      params['title'] = query['title'];
    }
    if (!isNullEmpty(query['notes'])) {
      params['notes'] = query['notes'];
    }

    // 金额区间：后端按账本币种主单位（BigDecimal）解析，原样下发文本
    for (final key in ['minAmount', 'maxAmount']) {
      final String text = (query[key] ?? '').toString().trim();
      if (text.isNotEmpty && num.tryParse(text) != null) {
        params[key] = text;
      }
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

}
