class AppConst {

  static const int defaultPageSize = 20;

  /// 后端分页参数（Spring Pageable 契约）：page 从 0 开始，size 为每页条数，
  /// 排序用 sort=字段,方向（如 createTime,desc）。
  static const int pageStart = 0;
  static const String pageParameter = 'page';
  static const String pageSizeParameter = 'size';
  static const String sortParameter = 'sort';

}
