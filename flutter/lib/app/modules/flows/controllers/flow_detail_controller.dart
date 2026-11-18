import 'package:get/get.dart';
import '/app/core/utils/message.dart';
import '/app/core/base/base_controller.dart';
import 'flows_controller.dart';
import '../flow_repository.dart';

/// 账单详情：后端没有单条查询（GET /money-flows/{id} 不存在），
/// 详情直接用列表行数据渲染，因此这里不再发请求；删除后回列表刷新。
class FlowDetailController extends BaseController {

  Map<String, dynamic> item;

  FlowDetailController(this.item);

  void delete() async {
    try {
      Message.showLoading();
      final bool result = await FlowRepository.delete(item['id']);
      if (result) {
        Get.back();
        if (Get.isRegistered<FlowsController>()) {
          Get.find<FlowsController>().reload();
        }
      }
    } catch (_) {
      // 失败提示由全局异常拦截器统一处理
    } finally {
      Message.disLoading();
    }
  }

}
