import 'package:moneynote/app/core/utils/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '/app/core/base/base_repository.dart';
import '/app/core/values/app_const.dart';
import '/app/core/base/enums.dart';
import '/app/core/base/base_controller.dart';
import '/app/modules/accounts/data/account_repository.dart';

class AccountsController extends BaseController {

  LoadDataStatus status = LoadDataStatus.initial;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> summary = {};
  int total = 0;
  late RefreshController refreshController;
  int tabIndex = 0;

  static const int pageSize = AppConst.defaultPageSize;

  void tabClick(int index) {
    tabIndex = index;
    update();
    reload();
  }

  @override
  void onInit() {
    super.onInit();
    refreshController = RefreshController(initialRefresh: false);
    reload();
  }

  /// 后端分页参数是 page（0 起）/ size，type 为整数枚举
  Map<String, dynamic> buildQuery(int page) {
    return {
      'page': page,
      'size': pageSize,
      'type': accountTabIndexToCode(tabIndex),
    };
  }

  Future<void> reload() async {
    try {
      status = LoadDataStatus.progress;
      update();
      final PageData pageData = await BaseRepository.queryPage('accounts', buildQuery(0));
      items = pageData.content;
      total = pageData.total;
      status = items.isEmpty ? LoadDataStatus.empty : LoadDataStatus.success;
      refreshController.refreshCompleted();
      refreshController.loadComplete();
      update();
      loadSummary();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

  /// 与列表同条件（tab 的 type）的余额汇总，用于列表顶部统计
  void loadSummary() async {
    try {
      summary = await AccountRepository.balanceSummary(type: accountTabIndexToCode(tabIndex));
      update();
    } catch (_) {
      summary = {};
      update();
    }
  }

  void loadMore() async {
    if (items.length >= total) {
      refreshController.loadNoData();
      return;
    }
    try {
      final PageData pageData = await BaseRepository.queryPage('accounts', buildQuery(items.length ~/ pageSize));
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

  @override
  void dispose() {
    super.dispose();
    refreshController.dispose();
  }

}
