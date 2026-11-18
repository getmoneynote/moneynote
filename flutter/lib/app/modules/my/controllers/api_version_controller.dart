import '/app/network/http.dart';
import '/app/core/base/enums.dart';
import '/app/core/base/base_controller.dart';

class ApiVersionController extends BaseController {

  LoadDataStatus status = LoadDataStatus.initial;
  String version = 'loading...';

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() async {
    try {
      status = LoadDataStatus.progress;
      update();
      // GET /version 返回 { data: { version: "0.1.3" } }，兼容直接返回字符串的写法
      final dynamic data = (await Http.get('version'))['data'];
      version = (data is Map ? data['version'] : data)?.toString() ?? '';
      status = LoadDataStatus.success;
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

}