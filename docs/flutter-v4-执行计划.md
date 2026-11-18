# Flutter v4 重构执行计划

目标：在 `flutter-v4/` 下新建 Flutter 项目，界面与功能与旧 `flutter/` 一致，接口全部对接 backend 的新 API；使用最新 Flutter SDK 与最新依赖，架构按移动端最佳实践重新设计。

---

## 一、调研结论

### 1.1 旧版 `flutter/`（1.0.44，GetX）

| 维度 | 旧实现 |
| --- | --- |
| 状态/路由 | GetX 4.6.6，`Get.to()` 命令式导航，无命名路由 |
| 网络 | Dio 5 + 手写拦截器，响应原样返回 `Map<String, dynamic>`，**无任何类型化模型** |
| 金额 | double（主单位），`toStringAsFixed(2)` 显示 |
| 枚举 | 字符串：`EXPENSE` / `INCOME` / `TRANSFER` / `ADJUST`、`CHECKING` / `CREDIT` / `ASSET` / `DEBT` |
| 页面 | 登录 / 账户（4 类 tab）/ 流水（列表·筛选·表单·详情）/ 图表（4 tab）/ 我的 |
| 特色功能 | 多分类多金额、附件（拍照/相册上传、WebView 预览）、余额调整、复制/退款/确认流水、9 套主题 + 深色、中英双语 |

### 1.2 新后端（`/api/v1`）与旧接口的差异（直接影响改造）

| 主题 | 旧接口 | 新接口 | 影响 |
| --- | --- | --- | --- |
| 金额单位 | 主单位小数 | **Long 最小单位（分）** | 全局引入 `Money` 工具，按币种 `decimalPlaces` 换算 |
| 枚举 | 字符串 | **int**：流水 1支出/2收入/3转账/4调整；账户 1活期/2信用/3资产/4贷款 | 枚举 + 展示名映射 |
| 流水 | `/balance-flows` | `/money-flows` | repository 重写 |
| 流水分类 | `categories[]` 多分类多金额 | **单个 `categoryId` + 单个 `amount`** | 表单结构简化，去掉“每个分类一个金额” |
| 附件 | `balance-flows/{id}/addFile`、`flow-files/*` | **后端完全没有文件能力** | 附件功能无法实现，只能砍掉 |
| 账户详情 | `GET accounts/{id}` | **无单条详情接口**，`/accounts` 列表行即详情数据 | 详情页由列表对象传入 + 可选重新拉列表 |
| 账户删/改 | `PUT accounts/{id}`、`PATCH toggle` | `PATCH accounts/{id}` 部分更新、`DELETE accounts/{id}` | 表单字段与提交逻辑调整 |
| 账户余额调整 | `POST accounts/{id}/adjust`（目标余额） | 同路径，`balance` 为**目标余额（分）**，且含 `include` | 调整表单适配 |
| 账户汇总 | `accounts/overview` → `[asset,debt,net]` | `accounts/netWorth` → `{totalAssets,totalLiabilities,netWorth}` | 我的页适配 |
| 账户概览 | — | `accounts/balanceSummary`（按类型汇总） | 账户页头部统计条（新增可选） |
| 图表 | `reports/expense-category` / `income-category` / `balance` | `money-flows/category-statistics?type=1\|2`、`accounts/balanceDistribution` | 图表数据源重写 |
| 初始化 | `initState` 返回 `{user, group, book}` | `initState` **只返回 `user`**（含 currentBookId、baseCurrency） | 启动需并行拉 `/books`、`/currencies/options` |
| 账本切换 | `setDefaultGroupAndBook/{gid-bid}` | `PATCH books/{id}/setDefault` | 我的页改造；无“账套 group”概念 |
| 选项列表 | `accounts/all`、`categories/all`… | `accounts/options`、`categories/tree`、`tags`、`payees`、`currencies/options` | 选择器数据源统一改造 |
| 汇率换算 | `currencies/calc` | **无换算接口**，用 `/currencies` 的 `usdRate` 本地算 | 本地金额换算工具 |
| 分页 | `current`（1 起）/`pageSize` | `page`（**0 起**）/`size` | 分页适配层 |
| AI / 提醒 / LLM / 注册 | 旧版无 | 新后端有 | 本次不做（见决策点） |

### 1.3 环境现状

- 全局 Flutter 为 **3.13.5 / Dart 3.1.2**（2023 年），不满足“最新版本”。
- 最新 stable：**Flutter 3.50.0 / Dart 3.14.0**（2026-11-11）。
- 机器上 `~/fvm/versions/3.10.2` 存在，但 `fvm` 命令不可用；无其他新 SDK。
- Android SDK 34 已装，但缺 `cmdline-tools` 且 license 未接受 → **APK 构建大概率失败**；Chrome/Web 可用。
- `flutter-v2/` 是上一次未完成的重写（约 4900 行，仍用 3.13 SDK + 旧依赖），本次**仅作参考，不复用代码**。

---

## 二、技术选型与架构

### 2.1 技术栈（全部取最新稳定版，用 `flutter pub add` 解析）

| 用途 | 选型 | 说明 |
| --- | --- | --- |
| SDK | Flutter 3.50.0 / Dart 3.14 | 独立安装在 `D:\Program\flutter3.50.0`，不动现有 3.13.5 |
| 状态管理 | `flutter_riverpod`（3.x） | 编译期安全、可测试、无全局单例 |
| 路由 | `go_router` | 声明式路由 + `redirect` 做登录态守卫 + `ShellRoute` 承载底部导航 |
| 网络 | `dio` | 拦截器：动态 baseUrl、Bearer、`Accept-Language`、错误归一化 |
| 模型 | `freezed` + `json_serializable` + `build_runner` | 不可变模型、`copyWith`、`fromJson`；`@JsonKey(defaultValue:)` 兜底 null |
| 本地存储 | `shared_preferences`（非敏感配置）+ `flutter_secure_storage`（token） | 服务器地址/主题/语言/当前账本 vs 访问令牌分离 |
| 图表 | `fl_chart` | 环形图 + 图例，替代 syncfusion（无需许可证） |
| 国际化 | 官方 `flutter_localizations` + `gen-l10n`（ARB） | 迁移旧版 100+ 条中英文案 |
| 日期/数字 | `intl` | 中英日期格式差异（`yyyy-MM-dd` / `MM/dd/yyyy`） |
| 图标资源 | `flutter_launcher_icons` | 复用旧 `assets/logo.png` |

### 2.2 分层结构

```
lib/
  main.dart                     # ProviderScope + 启动引导
  app/
    app.dart                    # MaterialApp.router + 主题 + 本地化
    router.dart                 # go_router 配置、登录守卫、ShellRoute
    shell/                      # 底部导航壳（账户/流水/记账/图表/我的）
  core/
    config/app_config.dart      # 版本号、默认分页、常量
    network/api_client.dart     # Dio 封装：get/post/patch/delete、拆信封
    network/api_exception.dart  # 类型化异常（401/403/404/409/422/500 + violations）
    network/interceptors.dart   # 注入 token / baseUrl / 语言 / 401 登出
    storage/preferences.dart    # 非敏感配置
    storage/token_store.dart    # 安全存储 token
    money/money.dart            # 分↔主单位、按 decimalPlaces 格式化、本地汇率换算
    format/date_format.dart
    theme/app_theme.dart        # Material 3 + 9 套主题色 + 深色
    l10n/                       # zh_CN / en_US ARB + 生成代码
    widgets/                    # 通用组件：状态页、详情行、选择器、金额输入、确认弹窗、下拉刷新列表
  data/
    models/                     # 按后端 VO 一比一建模（account/book/category/tag/payee/currency/money_flow/statistics/user）
    repositories/               # 每个领域一个 repository，只做 HTTP + JSON ↔ Model
  features/
    auth/                       # 登录（服务器地址 + 账号密码 + 语言）+ 会话状态
    accounts/                   # 列表(4 tab) / 详情 / 新建编辑 / 余额调整
    flows/                      # 列表(分页+排序+统计) / 筛选 / 表单 / 详情
    charts/                     # 支出/收入/资产/负债 4 tab + 筛选
    settings/                   # 我的：用户、净资产、当前账本、主题、语言、版本、退出
    select/                     # 通用单选/树形多选页
```

### 2.3 关键设计约定

1. **金额**：全部以 `int`（分）在模型与状态中流转，只在输入/展示层与 `Money` 互转；`decimalPlaces` 一律从接口字段取，不硬编码 2。
2. **错误**：`ApiException{status, message, violations}`；401 统一清 token 并跳登录；`violations` 映射成表单字段错误。
3. **分页**：`PageResult<T>{content, current(1 起), pageSize, total}`，`page = current - 1` 出站转换，避免把 0 基索引泄漏到 UI。
4. **状态**：每个列表一个 `AsyncNotifier`（含筛选条件 + 分页游标），表单用独立 `Notifier` 持有 draft；详情页以 id 为 family 参数。
5. **响应兼容**：`tags`/`children` 可能缺失或为 null，所有解析走 `?? const []`；列表模型忽略未知字段。
6. **进度可见**：每个阶段结束给出「已完成文件清单 + 未决问题」，不做静默大改。

---

## 三、实施阶段

### Phase 0 · 环境与骨架
1. 下载并解压 Flutter 3.50.0 到 `D:\Program\flutter3.50.0`（约 1.8 GB），`flutter --version` 校验。
2. 用该 SDK 在 `flutter-v4/` 执行 `flutter create`（platforms: android, ios, web），包名 `moneynote`。
3. 项目内加 `tool/flutter.cmd`（或 `.fvmrc` 风格说明）指向 3.50.0，避免误用全局 3.13.5。
4. `flutter pub add` 一次性加入最新依赖；`analysis_options.yaml` 收紧 lint。
5. 产出：可运行的空白 App + 依赖锁定。

### Phase 1 · 核心基础设施
- `ApiClient` + 拦截器 + 信封解析（`{success,data,message,violations}`）+ 错误映射。
- `Preferences` / `TokenStore`：`apiUrl`、`accessToken`、`locale`、`theme`、`currentBookId`。
- `Money`：分↔主单位、`decimalPlaces` 格式化、`usdRate` 交叉换算（替代旧 `currencies/calc`）。
- 主题：11 套（default + 9 色 + dark），Material 3，深色跟随系统/手动覆盖。
- 本地化：zh_CN / en_US ARB，迁移旧版全部 key。
- 通用组件：`LoadingView` / `EmptyView` / `ErrorView` / `DetailRow` / `OptionSheet` / `TreeSelectPage` / `AmountField` / `DateField` / `ConfirmDialog` / `PagedListView`。
- 产出：`core/` 完整，可被任意页面复用。

### Phase 2 · 数据层
按新 API 一比一建模 + repository：

| 模块 | 接口 |
| --- | --- |
| auth | `POST /login`、`POST /logout`、`GET /initState`、`GET /version` |
| book | `GET /books`、`PATCH /books/{id}/setDefault`（只读+切换即够） |
| currency | `GET /currencies`（取 usdRate）、`GET /currencies/options` |
| account | `GET /accounts`、`GET /accounts/options`、`POST /accounts`、`PATCH /accounts/{id}`、`DELETE /accounts/{id}`、`POST /accounts/{id}/adjust`、`GET /accounts/balanceSummary`、`GET /accounts/netWorth`、`GET /accounts/balanceDistribution` |
| category | `GET /categories/tree?type=&bookId=` |
| tag / payee | `GET /tags`、`GET /payees`（分页，取 size=1000） |
| moneyFlow | `GET /money-flows`、`POST`、`PATCH /{id}`、`DELETE /{id}`、`GET /statistics`、`GET /category-statistics` |

产出：模型 + 仓库 + 单元测试（JSON 解析 & Money 换算）。

### Phase 3 · 登录与导航壳
- 登录页：Logo、服务器地址、用户名、密码、语言切换、版本号；地址变更即时生效。
- 启动流程：有 token → `initState` → 并行拉 books/currencies → 进入主界面；失败回登录。
- `go_router`：`/login`、`/`（ShellRoute）、`/flows/:id`、`/accounts/:id` 等；未登录重定向。
- 底部导航：账户 / 流水 / 中间「记账」胶囊按钮 / 图表 / 我的（保留 `IndexedStack` 状态）。
- 产出：可登录进入 4 个空白 tab。

### Phase 4 · 账户模块
- 列表：4 个类型 tab（活期/信用/资产/贷款）+ 下拉刷新 + 分页 + 类型汇总条（`balanceSummary`）。
- 详情：字段与旧版一致（类型、名称、余额、币种、折算余额、信用额度、剩余额度、账单日/还款日、年利率、是否计入净资产、4 个能力开关、卡号复制、备注）；无附件。
- 表单：类型（编辑时锁定）、币种、名称、初始余额、信用额度/账单日/年利率（按类型显示）、5 个开关、卡号、备注。
- 余额调整：目标余额 + 账本 + 标题 + 时间 + 备注 + 计入统计。
- 产出：账户全流程可用，余额变动能在流水里看到 ADJUST 记录。

### Phase 5 · 流水模块
- 列表：分页 + 排序（时间/金额）+ 顶部收支结余统计（`/statistics`）+ 点击详情 / 长按复制。
- 筛选页：账本、类型、标题、账户、交易对象、分类（树形多选→CSV）、标签、时间区间、金额区间、是否确认、是否计入、备注；重置。
- 表单：支出/收入/转账三 tab；账本、标题、时间、账户、**单分类**、金额、换算金额（币种不同时，按 usdRate 自动算并允许手改）、标签、交易对象、确认/计入开关、备注；编辑/复制/退款三种入口。
- 详情：基础字段 + 确认 + 编辑 + 删除 + 复制 + 退款（无附件、无 PDF 预览）。
- 产出：旧版流水功能对齐（除附件）。

### Phase 6 · 图表模块
- 4 个 tab：支出分类 / 收入分类 / 资产分布 / 负债分布。
- 环形图（fl_chart）+ 中心合计 + 百分比图例，金额按后端最小单位格式化。
- 筛选页（仅前两个 tab 可用）：账本、标题、时间、分类、标签、交易对象、账户 + 5 个时间快捷区间。
- 产出：图表数据与 web-pc 报表口径一致。

### Phase 7 · 我的
- 用户名、净资产概览（`netWorth`，可刷新）、当前账本切换（`setDefault`）、主题、语言、服务器地址、App 版本、API 版本、退出登录。

### Phase 8 · 平台与收尾
- Android：`applicationId`、`label=MoneyNote`、`usesCleartextTraffic=true`、launcher icon。
- iOS：`Info.plist` 补 ATS 例外（旧版缺失，自建 http 服务器必需）、显示名、BundleId。
- 资产：logo、ARB。
- README：如何用 3.50.0 运行/构建；`.gitignore` 覆盖 `build/`、`.dart_tool/`。
- 静态检查与构建（是否执行见决策点 4）。

---

## 四、已确认决策（2026-11-17）

| # | 决策 | 落地影响 |
| --- | --- | --- |
| 1 | **砍掉附件功能** | 流水详情页去掉 `FlowFileList`、上传入口、`image_picker` / `webview_flutter` 依赖；表单与列表不出现 `hasFile`；后端无接口，不做占位。 |
| 2 | **流水收敛为单分类** | 表单 `Category` 由树形多选改单选；金额字段只有一个；提交 `{categoryId, amount}`；筛选仍支持多分类（`categoryIds` CSV），列表行只显示 `categoryName`。 |
| 3 | **独立安装 Flutter 3.50.0** | 装到 `D:\Program\flutter3.50.0`，不修改全局 3.13.5；`flutter-v4` 通过项目内脚本固定使用该 SDK。 |
| 4 | **允许构建验证** | 每阶段跑 `flutter analyze`，收尾跑 `flutter build web`；不尝试 APK（Android 工具链缺 `cmdline-tools`）。 |
| 5 | **不做新功能** | 提醒、LLM 配置、AI 对话、注册不在本次范围，保持“功能与旧版一致”。 |
| 6 | **包名沿用** | `applicationId` / BundleId 仍为 `cn.biq.moneynote`，可直接覆盖升级旧版。 |

由此产生的两处功能缺失（**明确接受**）：
- 流水不能挂图片附件，也不能在 App 内预览附件。
- 余额调整流水（type=4）不可编辑：`PATCH /money-flows/{id}` 的表单校验只允许 `type` 1..3，编辑调整记录属于接口不支持的行为；详情页只提供查看与删除，需要改余额就在账户详情重新做一次调整。

---

## 五、验收标准

- `flutter analyze` 零 error（warning 有明确理由）。
- Web 构建通过，能用真实后端完成：登录 → 记一笔支出 → 流水可见 → 账户余额变化 → 图表分类占比更新。
- 账户：4 类 tab、增删改、余额调整、详情字段齐全。
- 流水：筛选全条件生效、分页、编辑/复制/退款/确认/删除。
- 图表：4 tab 数据正确、筛选生效。
- 我的：切账本后流水与图表按新账本刷新；切主题/语言即时生效；退出后回登录页。
