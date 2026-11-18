import 'package:get/get.dart';
import '/app/core/base/base_controller.dart';
import '/app/core/base/base_repository.dart';
import '/app/core/base/enums.dart';
import '/app/modules/login/controllers/auth_controller.dart';
import '/app/network/http.dart';

/// 「我的」页数据：账本列表 + 本位币列表。
///
/// 新后端去掉了 group 概念，`initState` 只返回
/// `{ user: { username, currentBookId, baseCurrencyId, baseCurrencyDecimalPlaces, ... } }`，
/// 账本名/账本币种只能从 `GET /books` 取（BookListItem 带 isCurrent、currencyName），
/// 本位币名称只能从 `GET /currencies/options` 取（会话里只有 id 和小数位）。
class MyController extends BaseController {

  LoadDataStatus status = LoadDataStatus.initial;

  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> currencies = [];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      status = LoadDataStatus.progress;
      update();
      // books 只有分页列表接口（后端 Pageable），一次取够
      books = await BaseRepository.query('books', {
        'page': 0,
        'size': 1000,
      });
      currencies = await BaseRepository.options('currencies');
      status = books.isEmpty ? LoadDataStatus.empty : LoadDataStatus.success;
      update();
    } catch (_) {
      status = LoadDataStatus.failure;
      update();
    }
  }

  Map<String, dynamic>? get currentBook {
    for (final book in books) {
      if (book['isCurrent'] == true) return book;
    }
    return books.isEmpty ? null : books.first;
  }

  /// 账本显示名：账本本身带币种（不再有 group 币种），如「生活账本（人民币）」
  String bookLabel(Map<String, dynamic> book) {
    final String name = (book['name'] ?? '').toString();
    final String currency = (book['currencyName'] ?? '').toString();
    return currency.isEmpty ? name : '$name（$currency）';
  }

  String get currentBookLabel {
    final Map<String, dynamic>? book = currentBook;
    return book == null ? '' : bookLabel(book);
  }

  /// 账本下拉：账本名 + 账本币种，选中项由 MyOption 按 value 高亮
  List<Map<String, dynamic>> get bookOptions => books.map((book) => {
    'value': book['id'],
    'label': bookLabel(book),
  }).toList();

  Map<String, dynamic>? get currentBookOption {
    final Map<String, dynamic>? book = currentBook;
    if (book == null) return null;
    return {
      'value': book['id'],
      'label': bookLabel(book),
    };
  }

  Map<String, dynamic>? get baseCurrency {
    final dynamic id = Get.find<AuthController>().user?['baseCurrencyId'];
    if (id == null) return null;
    for (final currency in currencies) {
      if ('${currency['value']}' == '$id') return currency;
    }
    return null;
  }

  /// 币种显示名：名称 + 代码，如「人民币（CNY）」；CurrencyOption.label 只有名称
  String currencyLabel(Map<String, dynamic> currency) {
    final String label = (currency['label'] ?? '').toString();
    final String code = (currency['code'] ?? '').toString();
    if (label.isEmpty) return code;
    return code.isEmpty ? label : '$label（$code）';
  }

  String get baseCurrencyLabel {
    final Map<String, dynamic>? currency = baseCurrency;
    return currency == null ? '' : currencyLabel(currency);
  }

  List<Map<String, dynamic>> get currencyOptions => currencies.map((currency) => {
    'value': currency['value'],
    'label': currencyLabel(currency),
  }).toList();

  Map<String, dynamic>? get baseCurrencyOption {
    final Map<String, dynamic>? currency = baseCurrency;
    if (currency == null) return null;
    return {
      'value': currency['value'],
      'label': currencyLabel(currency),
    };
  }

  /// 切换当前账本：PATCH /books/{id}/setDefault，然后重新拉会话（initState 里的 currentBookId 要同步）
  Future<bool> changeBook(dynamic id) async {
    try {
      await Http.patch('books/$id/setDefault');
      await Get.find<AuthController>().refreshInitState();
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 切换本位币：PATCH /setBaseCurrency/{id}，响应直接是更新后的会话 VO
  Future<bool> changeBaseCurrency(dynamic id) async {
    try {
      final dynamic user = (await Http.patch('setBaseCurrency/$id'))['data'];
      if (user != null) {
        Get.find<AuthController>().applyUser(user);
      }
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

}
