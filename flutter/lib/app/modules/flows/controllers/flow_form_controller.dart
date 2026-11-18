import 'package:get/get.dart';
import '/app/core/utils/money.dart';
import '/app/core/utils/utils.dart';
import '/app/core/utils/message.dart';
import '/app/core/base/base_repository.dart';
import '/app/core/base/base_controller.dart';
import '/app/modules/login/controllers/auth_controller.dart';
import '/app/modules/flows/controllers/flow_detail_controller.dart';
import '/app/modules/flows/controllers/flows_controller.dart';
import '/app/modules/flows/flow_repository.dart';

/// 账单表单：对齐后端 MoneyFlowCreateForm
/// - 一条流水只有一个分类（旧版的「多分类拆金额」模型已不存在）
/// - 金额是「最小货币单位」整数，表单里输入的是主单位文本，提交时按币种精度换算
/// - 只有一个账户币种 ≠ 目标币种时才需要填折算金额（目标币种 = 转账的转入账户 / 收支的账本）
/// - type 创建后不可变，更新时后端忽略表单里的 type/bookId
class FlowFormController extends BaseController {

  bool valid = false;
  Map<String, dynamic> form = {};

  /// 账本 / 币种 / 账户 三个字典：金额精度与折算判断都依赖它们
  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> currencies = [];
  List<Map<String, dynamic>> accounts = [];

  /// 当前输入金额与折算金额的币种精度（文本框是主单位，提交时换算成最小单位）
  int amountDP = 2;
  int targetDP = 2;

  /// 字典未加载完时的兜底精度：用户本位币精度（比硬编码 2 位可靠）
  int _fallbackDP = 2;

  String type;
  int action;
  Map<String, dynamic> currentRow;

  FlowFormController(this.type, this.action, this.currentRow);

  @override
  void onInit() {
    super.onInit();
    final dynamic user = Get.find<AuthController>().initState['user'];
    _fallbackDP = (user is Map ? user['baseCurrencyDecimalPlaces'] : null) ?? 2;
    reset();
    _loadOptions();
  }

  // ---------------------------------------------------------------- 初始化

  void reset() {
    form = {
      'tags': <Map<String, dynamic>>[],
      'createTime': action == 2 ? currentRow['createTime'] : DateTime.now().millisecondsSinceEpoch,
      'confirm': action == 2 ? currentRow['confirm'] : true,
      'include': action == 2 ? currentRow['include'] : true,
      'notes': action == 2 ? currentRow['notes'] : null,
    };

    if (action == 1) {
      form['book'] = _defaultBook();
      amountDP = _bookDP();
      targetDP = amountDP;
    } else {
      _fillFromRow();
    }
    valid = _checkValid();
    update();
  }

  /// 编辑(2)/复制(3)/退款(4)：用列表行回填。复制与退款重置时间、备注、确认与统计开关，
  /// 退款额外把金额取负（后端约定：负数收支 = 退款记录，余额与统计自动回冲）。
  void _fillFromRow() {
    final bool isEdit = action == 2;
    final String rowType = flowCodeToType(currentRow['type']);

    form['book'] = {
      'value': currentRow['bookId'],
      'label': currentRow['bookName'] ?? '',
    };
    form['title'] = currentRow['title'];
    form['createTime'] = isEdit ? currentRow['createTime'] : DateTime.now().millisecondsSinceEpoch;
    form['confirm'] = isEdit ? currentRow['confirm'] : true;
    form['include'] = isEdit ? currentRow['include'] : true;
    form['notes'] = isEdit ? currentRow['notes'] : null;

    form['account'] = currentRow['accountId'] != null
        ? {
            'value': currentRow['accountId'],
            'label': currentRow['accountName'] ?? '',
            'currencySymbol': currentRow['amountCurrencySymbol'],
            'currencyDecimalPlaces': currentRow['amountCurrencyDecimalPlaces'],
          }
        : null;

    amountDP = currentRow['amountCurrencyDecimalPlaces'] ?? _bookDP();
    targetDP = currentRow['convertedCurrencyDecimalPlaces'] ?? _bookDP();

    // 退款只对支出/收入开放（后端允许负数收支 = 退款，余额与统计自动回冲）；
    // 转账退款语义是「反向转账」，不是负数转账，故意不在这里支持
    final bool negativeRefund = action == 4 && rowType != 'TRANSFER';
    final dynamic rawAmount = currentRow['amount'];
    final dynamic rawConverted = currentRow['convertedAmount'];
    form['amount'] = Money.formatAmountDisplay(
      negativeRefund ? _negate(rawAmount) : rawAmount,
      amountDP,
    );
    form['convertedAmount'] = currentRow['needConvert'] == true
        ? Money.formatAmountDisplay(negativeRefund ? _negate(rawConverted) : rawConverted, targetDP)
        : '';

    if (rowType == 'TRANSFER') {
      form['to'] = currentRow['toAccountId'] != null
          ? {
              'value': currentRow['toAccountId'],
              'label': currentRow['toAccountName'] ?? '',
              'currencyDecimalPlaces': currentRow['convertedCurrencyDecimalPlaces'],
              'currencySymbol': currentRow['convertedCurrencySymbol'],
            }
          : null;
      form['category'] = null;
      form['payee'] = null;
    } else {
      form['category'] = currentRow['categoryId'] != null
          ? {
              'value': currentRow['categoryId'],
              'label': currentRow['categoryName'] ?? '',
            }
          : null;
      form['payee'] = currentRow['payeeId'] != null
          ? {
              'value': currentRow['payeeId'],
              'label': currentRow['payeeName'] ?? '',
            }
          : null;
      form['to'] = null;
    }

    form['tags'] = (currentRow['tags'] as List? ?? [])
        .map((e) => {'value': e['id'], 'label': e['name'] ?? ''})
        .toList();
  }

  /// 账本、币种、账户三个字典：一次并行拉取，之后表单切换账户/账本不再请求
  Future<void> _loadOptions() async {
    try {
      final List<dynamic> results = await Future.wait([
        BaseRepository.query('books', {'page': 0, 'size': 1000}),
        BaseRepository.options('currencies'),
        BaseRepository.options('accounts'),
      ]);
      books = List<Map<String, dynamic>>.from(results[0] as List);
      currencies = List<Map<String, dynamic>>.from(results[1] as List);
      accounts = List<Map<String, dynamic>>.from(results[2] as List);
      _applyLoadedOptions();
      update();
    } catch (_) {
      update();
    }
  }

  /// 字典到达后补齐：新增态的默认账本、编辑态账户的币种精度（回填时账户只有 id 和名称）
  void _applyLoadedOptions() {
    final dynamic book = form['book'];
    if (book == null || (book['label'] ?? '').isEmpty) {
      form['book'] = _defaultBook();
    }
    for (final key in ['account', 'to']) {
      final dynamic selected = form[key];
      if (selected == null) continue;
      final Map<String, dynamic>? matched = _findOption(accounts, selected['value']);
      if (matched != null) {
        form[key] = {...selected, ...matched};
      }
    }
    _refreshCurrency();
  }

  // ---------------------------------------------------------------- 字典与币种

  Map<String, dynamic>? _defaultBook() {
    if (books.isNotEmpty) {
      final Map<String, dynamic> current = books.firstWhere(
        (b) => b['isCurrent'] == true,
        orElse: () => books.first,
      );
      return {'value': current['id'], 'label': current['name'] ?? ''};
    }
    final dynamic user = Get.find<AuthController>().initState['user'];
    final dynamic currentBookId = user is Map ? user['currentBookId'] : null;
    if (currentBookId != null) {
      return {'value': currentBookId, 'label': ''};
    }
    return null;
  }

  Map<String, dynamic>? _findBook(dynamic id) {
    if (id == null) return null;
    for (final book in books) {
      if ('${book['id']}' == '$id') return book;
    }
    return null;
  }

  Map<String, dynamic>? _findOption(List<Map<String, dynamic>> options, dynamic value) {
    if (value == null) return null;
    for (final option in options) {
      if ('${option['value']}' == '$value') return option;
    }
    return null;
  }

  int _currencyDP(dynamic currencyId) {
    if (currencyId == null) return _fallbackDP;
    for (final currency in currencies) {
      if ('${currency['value']}' == '$currencyId') {
        return currency['decimalPlaces'] ?? _fallbackDP;
      }
    }
    return _fallbackDP;
  }

  String _currencyCode(dynamic currencyId) {
    if (currencyId == null) return '';
    for (final currency in currencies) {
      if ('${currency['value']}' == '$currencyId') {
        return currency['code'] ?? '';
      }
    }
    return '';
  }

  dynamic get _bookCurrencyId => _findBook(form['book']?['value'])?['currencyId'];

  int _bookDP() => _currencyDP(_bookCurrencyId);

  /// 金额所在币种：选了账户用账户币种，未归属收/支用账本币种
  dynamic get _amountCurrencyId => form['account']?['currencyId'] ?? _bookCurrencyId;

  /// 折算目标币种：转账为转入账户币种，收/支为账本币种。
  /// 注意：`a?[k]` 不能直接写在三元表达式的 then 分支里（Dart 3.1 会按条件运算符解析报错），
  /// 故此处拆成 if/else。
  dynamic get _targetCurrencyId {
    if (type == 'TRANSFER') {
      final dynamic to = form['to'];
      return to is Map ? to['currencyId'] : null;
    }
    return _bookCurrencyId;
  }

  String get amountCode => _currencyCode(_amountCurrencyId);

  String get convertCode => _currencyCode(_targetCurrencyId);

  Map<String, dynamic>? get account => form['account'];

  Map<String, dynamic>? get toAccount => form['to'];

  bool get needConvert {
    if (account == null) return false;
    final dynamic target = _targetCurrencyId;
    final dynamic source = _amountCurrencyId;
    if (target == null || source == null) {
      // 字典没加载完（或账户已不在字典里）：编辑态按行上的既有结论兜底
      return action != 1 && currentRow['needConvert'] == true;
    }
    return '$source' != '$target';
  }

  /// 账户/转入账户/账本变化后重算精度；折算金额同时清空，避免沿用旧币种的数值
  void _refreshCurrency() {
    amountDP = form['account']?['currencyDecimalPlaces'] ?? _bookDP();
    if (type == 'TRANSFER') {
      targetDP = form['to']?['currencyDecimalPlaces'] ?? _currencyDP(_targetCurrencyId);
    } else {
      targetDP = _bookDP();
    }
  }

  // ---------------------------------------------------------------- 交互

  void changeBook(dynamic value) {
    form['book'] = value;
    // 分类/标签/交易对象是账本级资源，换账本后旧值失效
    form['category'] = null;
    form['payee'] = null;
    form['tags'] = [];
    form['convertedAmount'] = '';
    _refreshCurrency();
    valid = _checkValid();
    update();
  }

  /// 新增态切换类型（支出/收入/转账）
  void tabClick(int index) {
    if (index == 0) {
      type = 'EXPENSE';
    } else if (index == 1) {
      type = 'INCOME';
    } else if (index == 2) {
      type = 'TRANSFER';
    } else {
      throw Exception('index error');
    }
    form['category'] = null;
    form['payee'] = null;
    form['to'] = null;
    form['convertedAmount'] = '';
    _refreshCurrency();
    valid = _checkValid();
    update();
  }

  void changeAccount(dynamic value) {
    form['account'] = value;
    form['convertedAmount'] = '';
    _refreshCurrency();
    valid = _checkValid();
    update();
  }

  void changeToAccount(dynamic value) {
    form['to'] = value;
    form['convertedAmount'] = '';
    _refreshCurrency();
    valid = _checkValid();
    update();
  }

  void changeCategory(dynamic value) {
    form['category'] = value;
    valid = _checkValid();
    update();
  }

  void changePayee(dynamic value) {
    form['payee'] = value;
    update();
  }

  void changeTags(List<dynamic> values) {
    form['tags'] = values;
    update();
  }

  void changeAmount(String value) {
    form['amount'] = value;
    valid = _checkValid();
    update();
  }

  void changeConvertedAmount(String value) {
    form['convertedAmount'] = value;
    valid = _checkValid();
    update();
  }

  void checkValid() {
    valid = _checkValid();
    update();
  }

  // ---------------------------------------------------------------- 提交

  /// 退款取负：后端 Long 金额，转义前先按数字解析，避免字符串取负抛错
  dynamic _negate(dynamic value) {
    if (value == null) return null;
    final num? number = num.tryParse('$value');
    return number == null ? value : -number;
  }

  bool _checkValid() {
    if (form['book'] == null) return false;
    final double? amount = _number(form['amount']);
    if (amount == null) return false;
    if (type == 'TRANSFER') {
      if (amount < 0) return false;
      if (form['account'] == null || form['to'] == null) return false;
      if ('${form['account']['value']}' == '${form['to']['value']}') return false;
    } else if (form['category'] == null) {
      return false;
    }
    if (needConvert) {
      final double? converted = _number(form['convertedAmount']);
      if (converted == null) return false;
      if (type == 'TRANSFER' && converted < 0) return false;
    }
    return true;
  }

  double? _number(dynamic value) {
    final String text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Map<String, dynamic> buildForm() {
    final List<dynamic> tags = form['tags'] ?? [];
    final Map<String, dynamic> payload = {
      'bookId': form['book']?['value'],
      'type': flowTypeToCode(type),
      'title': isNullEmpty(form['title']) ? null : form['title'],
      'notes': isNullEmpty(form['notes']) ? null : form['notes'],
      'createTime': form['createTime'],
      'accountId': form['account']?['value'],
      'amount': Money.displayToMinor(form['amount'], amountDP),
      'convertedAmount': needConvert ? Money.displayToMinor(form['convertedAmount'], targetDP) : null,
      'confirm': form['confirm'] ?? true,
      'include': form['include'] ?? true,
      'tagIds': tags.map((e) => e['value']).toList(),
    };
    if (type == 'TRANSFER') {
      payload['toAccountId'] = form['to']?['value'];
      payload['categoryId'] = null;
      payload['payeeId'] = null;
    } else {
      payload['toAccountId'] = null;
      payload['categoryId'] = form['category']?['value'];
      payload['payeeId'] = form['payee']?['value'];
    }
    return payload;
  }

  Future<void> submit() async {
    if (!valid) return;
    try {
      Message.showLoading();
      final Map<String, dynamic> payload = buildForm();
      final bool ok = action == 2
          ? await FlowRepository.update(currentRow['id'], payload)
          : await FlowRepository.create(payload);
      if (!ok) return;
      Get.back();
      if (Get.isRegistered<FlowsController>()) {
        Get.find<FlowsController>().reload();
      }
      // 详情页数据来自列表行，更新后已过时：一并关闭，回到刷新后的列表
      if (action == 2 && Get.isRegistered<FlowDetailController>()) {
        Get.back();
      }
    } catch (_) {
      // 失败提示由全局异常拦截器统一处理
    } finally {
      Message.disLoading();
    }
  }

}
