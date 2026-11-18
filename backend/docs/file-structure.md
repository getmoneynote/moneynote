# 项目结构

> 本文以 `backend/` 工程为主，内容与实际代码同步（最后同步：2026-11-14）。
> 仓库级说明见根目录 `CLAUDE.md`；编码规范见 `docs/code-convention.md`。

## 仓库根目录

```
moneynote-api/
├── backend/                      # Spring Boot 后端（本文重点）
├── web-pc/                       # 前端应用（Node / pnpm 项目）
├── help/                         # 帮助站（独立 Node 项目）
├── docs/                         # 跨端经验笔记（前端经验 / 后端经验 / 线程模型 / todo）
├── README.md / CLAUDE.md / AGENT.md
├── .gitignore / .dockerignore
├── Dockerfile                    # 生产镜像（多阶段：镜像内构建 web-pc + 后端 + JRE）
├── docker-compose.yml
├── docker-compose.release.yml
└── entrypoint.sh
```

Docker 相关文件（`Dockerfile` / `docker-compose*.yml` / `entrypoint.sh` /
`.dockerignore`）统一放在**仓库根目录**，构建上下文也是仓库根目录；
`docker compose up -d` 在根目录执行，运行期数据仍写在 `backend/data`、`backend/config`。

## backend/ 顶层

```
backend/
├── pom.xml                       # Maven 配置（Java 21, Spring Boot 4.1.0, Spring AI 2.0.2）
├── mvnw / mvnw.cmd / .mvn/       # Maven Wrapper
├── CLAUDE.md / AGENTS.md         # 后端上下文与规范入口
├── LICENSE / .gitignore / .gitattributes / .claudeignore
├── config/
│   └── db-config.properties      # 安装向导生成的数据库配置（运行时读写）
├── data/                         # H2 本地开发数据 + SQL 备份（运行期生成）
│   ├── moneynote.mv.db / moneynote.lock.db
│   └── moneynote-*.sql / schema-*.sql / *.bak-*   # 备份与 schema 导出
├── backups/                      # 备份产物（backup-<时间戳>/db-config.properties、*.sql、*.zip）
├── scripts/
│   └── backup-h2.sh              # H2 数据库备份脚本
├── specs/                        # 产品/架构/API 规格：PRD / SPEC / ARCHITECTURE / API
├── docs/                         # 开发规范文档
│   ├── api-conventions.md
│   ├── code-convention.md
│   ├── file-structure.md         # 本文
│   └── issue-initstate-stale-currentbook.md
├── notes/                        # 零散笔记：db-setup / restful最佳实践 / docker发布命令 / todo
└── src/main/
    ├── java/com/moneynote/       # 见下文
    └── resources/                # 见下文
```

`.idea/`、`.claude/`、`target/` 为 IDE / 构建产物，不纳入结构说明；当前没有 `src/test`。

## Java 源码 `src/main/java/com/moneynote/`

```
├── Application.java              # 启动类：按数据库是否已配置选择正式 / Setup 模式
├── SetupApplication.java         # Setup 模式启动类（仅扫描 setup 包，排除数据源/JPA 自动配置）
├── TestController.java
│
├── account/                      # 账户模块
│   ├── Account.java              # 实体
│   ├── AccountController.java    # REST 接口
│   ├── AccountService.java       # 业务逻辑（含余额/统计）
│   ├── AccountRepository.java    # JPA 仓储（含 Specification 查询）
│   ├── AccountCreateForm.java    # 创建 DTO
│   ├── AccountUpdateForm.java    # 更新 DTO
│   ├── AccountQueryForm.java     # 查询 DTO
│   ├── AccountListItem.java      # 列表项 DTO
│   ├── AccountOption.java        # 下拉选项 DTO
│   ├── AccountOptionQueryForm.java # 账户选项查询 DTO
│   ├── AdjustBalanceAddForm.java # 余额调整 DTO
│   ├── AccountBalanceSummary.java # 账户余额汇总
│   ├── BalanceDistribution.java  # 余额分布统计
│   ├── NetWorthSummary.java      # 净资产汇总
│   └── AccountChartItem.java     # 账户图表数据项
│
├── base/                         # 基础抽象层
│   ├── BaseEntity.java           # 实体基类
│   ├── BaseRepository.java       # Repository 基类
│   ├── BaseDetails.java          # 详情 DTO 基类
│   ├── IdAndNameDetails.java     # 通用 id+name DTO
│   └── SelectOption.java         # 下拉选项 VO
│
├── book/                         # 账本模块
│   ├── Book.java                 # 实体
│   ├── BookController.java
│   ├── BookService.java
│   ├── BookRepository.java
│   ├── BookCreateForm.java       # 创建 DTO
│   ├── BookUpdateForm.java       # 更新 DTO
│   └── BookListItem.java         # 列表项 DTO
│
├── category/                     # 分类模块（树形结构）
│   ├── Category.java             # 实体（继承 TreeEntity）
│   ├── CategoryController.java
│   ├── CategoryService.java
│   ├── CategoryRepository.java
│   ├── CategoryCreateForm.java   # 创建 DTO
│   ├── CategoryUpdateForm.java   # 更新 DTO
│   └── CategoryTreeNode.java     # 分类树节点 DTO
│
├── chat/                         # AI 会话与 Agent（结构较深，见下一节）
│
├── config/                       # 配置
│   ├── ApiPrefixConfig.java      # 自动为 RestController 添加 /api/v1 前缀
│   ├── AuthInterceptor.java      # 认证拦截器（Bearer Token 校验）
│   ├── SpaForwardFilter.java     # SPA 路由支持（正式模式）
│   └── WebConfig.java            # 拦截器注册 + CORS 配置
│
├── currency/                     # 货币模块
│   ├── Currency.java             # 实体
│   ├── CurrencyController.java
│   ├── CurrencyService.java
│   ├── CurrencyRepository.java
│   ├── CurrencyCreateForm.java   # 创建 DTO
│   ├── CurrencyUpdateForm.java   # 更新 DTO
│   ├── CurrencyQueryForm.java    # 查询 DTO
│   ├── CurrencyListItem.java     # 列表项 DTO
│   └── CurrencyOption.java       # 下拉选项 DTO
│
├── exception/                    # 异常处理
│   ├── BusinessException.java    # 业务异常基类（禁止堆栈填充）
│   ├── GlobalExceptionHandler.java # 全局异常处理器
│   ├── ResourceNotFoundException.java   # 404 路径级主资源缺失
│   ├── ResourceInvalidException.java    # 400 引用的辅助资源无效
│   ├── ResourceDuplicateException.java  # 资源重复
│   ├── ResourceProtectedException.java  # 受保护资源不可操作
│   ├── ResourceReferencedException.java # 资源已被引用，不可删除
│   ├── ForbiddenException.java   # 403
│   └── UnauthorizedException.java # 401
│
├── llm/                          # 大模型配置（配置存在数据库，按用户隔离）
│   ├── LlmConfig.java            # 实体（t_llm_config）
│   ├── LlmConfigController.java
│   ├── LlmConfigService.java
│   ├── LlmConfigRepository.java
│   ├── LlmConfigCreateForm.java  # 创建 DTO
│   ├── LlmConfigUpdateForm.java  # 更新 DTO
│   ├── LlmConfigTestForm.java    # 连通性测试 DTO
│   ├── LlmConfigListItem.java    # 列表项 DTO
│   └── LlmClientFactory.java     # 运行时按配置构建 ChatClient（跳过启动期自动配置）
│
├── moneyflow/                    # 收支流水模块
│   ├── MoneyFlow.java            # 实体
│   ├── MoneyFlowController.java
│   ├── MoneyFlowService.java
│   ├── MoneyFlowRepository.java  # JPA 仓储（含 Specification 与自定义统计）
│   ├── MoneyFlowRepositoryCustom.java  # 自定义统计查询接口
│   ├── MoneyFlowRepositoryImpl.java    # 自定义统计查询实现
│   ├── MoneyFlowCreateForm.java  # 创建 DTO
│   ├── MoneyFlowQueryForm.java   # 查询 DTO
│   ├── MoneyFlowListItem.java    # 列表项 DTO
│   ├── MoneyFlowSummary.java     # 收支汇总
│   ├── CategoryStatistics.java   # 分类统计结果
│   └── CategoryChartItem.java    # 分类图表数据项
│
├── payee/                        # 收款人/付款人模块
│   ├── Payee.java                # 实体
│   ├── PayeeController.java
│   ├── PayeeService.java
│   ├── PayeeRepository.java
│   ├── PayeeCreateForm.java      # 创建 DTO
│   ├── PayeeUpdateForm.java      # 更新 DTO
│   ├── PayeeQueryForm.java       # 查询 DTO
│   └── PayeeListItem.java        # 列表项 DTO
│
├── reminder/                     # 提醒模块
│   ├── Reminder.java             # 实体
│   ├── ReminderController.java
│   ├── ReminderService.java
│   ├── ReminderRepository.java
│   ├── ReminderCreateForm.java   # 创建 DTO
│   ├── ReminderUpdateForm.java   # 更新 DTO
│   ├── ReminderQueryForm.java    # 查询 DTO
│   └── ReminderListItem.java     # 列表项 DTO
│
├── response/                     # 响应封装
│   ├── SimpleResponse.java       # 响应基类（success 标志）
│   ├── DataResponse.java         # 携带业务数据（继承 SimpleResponse）
│   ├── MessageResponse.java      # 携带提示文案（继承 SimpleResponse）
│   ├── PageResponse.java         # 分页数据响应（继承 DataResponse）
│   ├── ValidationErrorResponse.java # 校验失败响应（继承 MessageResponse）
│   └── Violation.java            # 校验违规详情
│
├── setup/                        # 首次启动安装向导
│   ├── SetupController.java      # /setup 向导接口（仅未配置数据库时注册）
│   ├── SetupRedirectFilter.java  # setup 模式下所有请求 302 到 /setup
│   └── db/
│       ├── DbConfig.java         # 配置项 POJO
│       ├── DbConfigHolder.java   # 读写 config/db-config.properties
│       ├── DbType.java           # 数据库类型枚举
│       └── DynamicDataSourceConfig.java # 动态 DataSource（@ConditionalOnProperty）
│
├── tag/                          # 标签模块
│   ├── Tag.java                  # 实体
│   ├── TagController.java
│   ├── TagService.java
│   ├── TagRepository.java
│   ├── TagCreateForm.java        # 创建 DTO
│   ├── TagUpdateForm.java        # 更新 DTO
│   ├── TagQueryForm.java         # 查询 DTO
│   └── TagListItem.java          # 列表项 DTO
│
├── tagrelation/                  # 标签关联（流水 ↔ 标签）
│   └── TagRelation.java          # 实体
│
├── tree/                         # 树形结构工具
│   ├── TreeEntity.java           # 树形实体基类（parent/level/name）
│   ├── TreeNode.java             # 树节点 DTO
│   └── TreeUtils.java            # 扁平列表 → 树形结构转换
│
├── user/                         # 用户模块
│   ├── User.java                 # 实体
│   ├── UserRepository.java
│   ├── UserService.java          # 注册/登录
│   ├── UserController.java
│   ├── UserConverter.java        # 实体 ↔ VO 转换
│   ├── UserExceptionHandler.java # user 模块专属异常处理（仅作用于 UserController）
│   ├── LoginForm.java            # 登录 DTO
│   ├── RegisterForm.java         # 注册 DTO
│   ├── LoginSuccessVo.java       # 登录成功响应（携带 accessToken）
│   ├── InitStateResponse.java    # 初始化状态响应
│   ├── UserSessionVo.java        # 用户会话 VO
│   ├── SessionInfo.java          # 会话信息
│   ├── SessionManager.java       # 会话管理（Token 生成/查询）
│   ├── CurrentUserHolder.java    # ThreadLocal 当前用户 ID
│   ├── InvalidCredentialsException.java # 登录失败业务异常
│   ├── ValidUsername.java        # 用户名校验注解
│   └── ValidPassword.java        # 密码校验注解
│
├── utils/                        # 工具类
│   ├── CacheHolder.java          # 内存缓存（token→userId, userId→SessionInfo）
│   ├── MessageResolver.java      # 统一国际化消息解析器
│   ├── ClasspathResources.java   # classpath 文本资源读取（UTF-8 / 缺失即失败）
│   └── WebUtils.java             # Web 工具（解析 Bearer Token）
│
└── validate/                     # 组合校验注解
    ├── ValidName.java            # 非空 + 长度 ≤ 64
    └── ValidNotes.java           # 长度 ≤ 1024
```

## AI 会话模块 `chat/`

消息接口为「一条 Agent 固定时间线」，以 `(当前用户, agentCode)` 定位，
通过 SSE 流式返回；文件按「接口/持久化 → Agent → 消息块 → 事件 → 生成管线」分层。

```
chat/
├── ChatContext.java              # 一次生成所需的上下文（record）
├── ChatHistoryMessage.java       # 历史消息视图
├── ChatTransactionService.java   # 消息落库的短事务 + 启动清扫
├── GeneratingMessageSweepRunner.java # 启动时把残留 GENERATING 消息置为 ERROR
├── Message.java                  # 消息实体（状态 + 内容块）
├── MessageController.java        # /chat/agents/{agentCode}/messages（SSE + 块提交）
├── MessageService.java           # 校验 → 初始化 → 装配上下文
├── MessageRepository.java        # JPA 仓储（含悲观锁查询）
├── MessageListItem.java          # 列表项 DTO
├── MessageSendForm.java          # 发送消息 DTO
│
├── agent/                        # Agent 抽象与编排
│   ├── Agent.java                # Agent 接口（code + stream）
│   ├── AbstractLlmAgent.java     # LLM Agent 基类（构造期加载 system prompt）
│   ├── AgentRegistry.java        # 启动期收集所有 Agent Bean，按 code 建只读索引
│   ├── AgentOrchestrator.java    # 按 code 分发并组织事件流
│   ├── AgentRequest.java         # Agent 请求（携带历史）
│   ├── AgentContext.java         # Agent 执行上下文（record）
│   ├── AgentEvent.java           # Agent 事件（sealed）
│   ├── AgentExecution.java       # Agent 执行结果（code + 事件流）
│   ├── ChatResponseParser.java   # 解析模型输出
│   ├── ChatResponseProcessor.java # 处理模型响应流
│   ├── ReasoningNormalizer.java # 推理内容归一化
│   │
│   ├── account/                  # 账户分析 Agent → prompts/account-analysis
│   │   ├── AccountAgent.java
│   │   ├── AccountAnalysisService.java
│   │   ├── AccountAnalysisResponse.java
│   │   ├── AccountAnalysisItem.java
│   │   ├── AccountAnalysisCurrency.java
│   │   ├── AccountBalanceTool.java  # 只读工具：账户余额
│   │   └── AccountChartTool.java    # 只读工具：账户图表
│   ├── bookkeeping/              # 记账 Agent → prompts/bookkeeping
│   │   ├── BookkeepingAgent.java
│   │   └── BookkeepingDraftTool.java # 生成记账表单草稿（不落库）
│   ├── moneyflow/                # 流水分析 Agent → prompts/moneyflow-analysis
│   │   └── MoneyFlowAgent.java
│   └── general/                  # 通用问答 Agent → prompts/general-chat
│       └── GeneralAgent.java
│
├── block/                        # 消息内结构化块（图表 / 可提交表单）
│   ├── BlockData.java            # 块数据 sealed 接口（permits Chart / Form）
│   ├── BlockType.java            # 块类型枚举
│   ├── ChartBlockData.java       # 图表块数据
│   ├── FormBlockData.java        # 表单块数据
│   ├── FormStatus.java           # 表单状态枚举
│   ├── MessageBlock.java         # 单个消息块
│   ├── MessageBlocks.java        # 消息块集合与序列化
│   ├── BlockCollector.java       # 从流式输出收集块
│   ├── BlockActions.java         # 块动作常量
│   ├── MessageBlockSubmitForm.java # 表单块提交 DTO
│   └── ChatBlockActionService.java # 表单提交落库（悲观锁防重复，与流无关）
│
├── event/                        # SSE 事件协议
│   ├── ChatEvent.java            # 事件载体（record）
│   ├── ChatEventType.java        # 事件类型枚举
│   ├── ChatEventFactory.java     # 事件构造
│   ├── ChatEventConverter.java   # Agent 事件 → SSE 事件映射
│   ├── SseTransport.java         # SSE 传输封装
│   └── payload/
│       ├── StartData.java        # start 事件负载
│       ├── FinishData.java       # finish 事件负载
│       └── ErrorData.java        # error 事件负载
│
└── stream/                       # 生成生命周期管线
    ├── GenerationInput.java      # 一次生成的输入（record）
    ├── GenerationPipeline.java   # start → Agent 事件流 → 终态落库 → finish
    ├── MessageDraft.java         # 流式内容累积草稿
    └── TerminalFinalizer.java    # finish / error / cancel 终态落库
```

## 资源文件 `src/main/resources/`

```
├── application.properties        # 主配置（端口 9096、JPA、H2 控制台、关闭 Spring AI 启动期自动配置）
├── messages.properties           # 业务消息 i18n（默认 / en_US / zh_CN）
├── messages_en_US.properties
├── messages_zh_CN.properties
├── ValidationMessages.properties # 校验消息 i18n（默认 / en_US / zh_CN）
├── ValidationMessages_en_US.properties
├── ValidationMessages_zh_CN.properties
├── book-templates/
│   └── personal.json             # 内置账本模板
├── prompts/                      # 各 Agent 的 system prompt（构造期加载，缺失即启动失败）
│   ├── account-analysis/system.md
│   ├── bookkeeping/system.md
│   ├── general-chat/system.md
│   └── moneyflow-analysis/system.md
├── public/                       # 前端预构建静态资源快照（本地运行用；生产镜像会重新构建替换）
│   ├── index.html
│   ├── favicon.ico
│   ├── logo.svg
│   ├── umi.*.js / umi.*.css      # 带 hash 的构建产物（hash 随前端构建变化）
│   ├── icons/
│   │   ├── icon-128x128.png      # PWA 图标
│   │   ├── icon-192x192.png
│   │   └── icon-512x512.png
│   └── scripts/loading.js
└── setup/                        # 首次启动安装向导页面
    ├── index.html
    └── logo.svg
```
