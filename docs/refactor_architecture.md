# 游戏生产级重构执行路线图

> 状态：执行基线 v2.0
>
> 扫描日期：2026-07-12
>
> 规范优先级：`AGENTS.md`、`docs/project_architecture_rules.md` 高于本文。本文只负责把生产规范落成可执行迁移路线，不替代规范。
>
> 目标：在不改变已完成玩法结果和主要界面行为的前提下，将项目重构为可验证、可维护、适合 AI 持续执行的生产级 Godot 模块化单体。

## 1. 已确认的产品边界

### 1.1 本轮必须完成

- 覆盖全部已经完成且当前可运行的功能，保持玩法结果和主要界面行为不变。
- 重构技能系统，包括当前主动技能、被动技能、Buff、释放策略和战斗接入。
- 保留并重构功法系统，包括当前选择、装备、熟练度及其对修炼和属性的既有效果。
- 保留现有 UI 视觉、布局和交互结果；允许调整 `.tscn` 节点组织、信号、绑定和脚本。
- 建立新的单自动存档、独立设置、配置查询、状态所有权、导航和测试体系。
- 允许调整所有代码目录、脚本、内部 API、Autoload 和数据结构。
- 最终删除迁移期门面、旧兼容和无调用代码，不把临时架构留在成品中。

### 1.2 只保留界面和设计

- 大道系统。
- 自主研读与知识成长；保留现有界面和数据设计，后续可独立重新开发。
- 经 Phase 0 审计判定为尚未完成或只有占位界面的其他功能。

这些功能保留现有界面资产和未来模块边界，但本轮不补玩法、不建立空 service/factory/interface，也不伪造可运行数据。技能和功法系统不属于此范围。

### 1.3 明确不做

- 不兼容任何旧存档；新架构使用全新 schema。
- 不开发新玩法，不调整伤害、价格、掉落、概率等数值平衡。
- 不接入 Steamworks、成就、云存档、创意工坊、联机或手柄。
- 不做性能专项，也不预建对象池、异步加载、页面缓存或复杂虚拟化。
- 不重新设计现有美术与 UI 视觉。
- 不为每个函数绘制 UML 或维护易过期的静态调用图。

### 1.4 发布约束

- 平台：Windows Steam 单机游戏。
- 输入：键盘和鼠标。
- 设计分辨率：`1920×1080`；最低支持：`1280×720`。
- 显示模式：窗口化、无边框窗口、全屏。
- 首发语言：简体中文；玩家可见文本使用 `tr()`/翻译资源入口，但本轮不制作其他语言内容。

## 2. 当前基线与不一致

Phase 0 从 HEAD `29766807` 和仅本文未提交改写的工作区开始。以下数字只记录 2026-07-12 的阶段验收结果，不作为永久验收逻辑。

| 项目 | Phase 0 初始 | Phase 0 验收 |
| --- | --- | --- |
| GDScript | 221 个 | 227 个（新增测试） |
| 场景 | 85 个 | 84 个（删除失效场景） |
| Autoload | 13 个 | 13 个；Phase 1 开始收敛 |
| `npm run validate` | 仅 4 个 Node 检查且失败 | 完整门禁通过 |
| 技能配置 | 33 项未登记效果错误 | 39 个技能通过 |
| 道具配置 | 34 项未登记效果错误 | 47 个道具通过 |
| 大道配置 | 通过；仅保留设计 | 通过；仅保留设计 |
| 功法配置 | 通过 | 15 个谱系、83 层通过；必须保留 |
| 孤立 `.gd.uid` | 4 个 | 0 个 |
| Route smoke | 未覆盖 | 20 个场景通过，无 ERROR |

Phase 0 已处理：

1. 确认历练 JSON 已齐全，旧文档记录过时。
2. 删除 `character_creation.json` 残余依赖，姓名固定为 1–12 个字符。
3. 修正 Node 校验器对受保护效果表原样结构的误读，并保护 11 个合法效果 ID。
4. 将配置、UID/资源、Godot characterization、20 route smoke、启动和 `git diff --check` 接入唯一 `npm run validate`。
5. 删除 4 个孤立 UID 和无引用且缺脚本的旧地点选择场景。
6. 最终目标保持 3 个 Autoload；Overlay 由 `AppRoot` 持有，不建立万能 Result。

## 3. 重构原则

1. **完整目标、小步落地。** 最终架构一次设计清楚，实施必须拆成始终可验证、可回滚的垂直阶段。
2. **先刻画行为，再移动代码。** 没有最小行为检查的模块不得开始结构迁移。
3. **依赖向内。** `presentation -> application -> domain/core`；基础设施实现依赖领域定义的边界，不反向污染领域。
4. **状态唯一所有者。** 静态配置、长期存档、局内 session、UI 临时状态和缓存必须分开。
5. **UI 只表达意图。** UI 渲染快照并发出用户操作，不读取可变存档、不计算业务规则、不直接提交状态。
6. **原表直接查询。** Excel 原样导出的 JSON 是运行时配置；只允许薄查询封装，不生成第二份中间配置或通用 Definition 层。
7. **边界才建 Contract。** 只在跨模块、跨场景、存档和稳定 UI 快照处使用 typed contract；模块内部使用普通值和明确类型。
8. **失败要明确。** 配置、资源、存档和 payload 非法时返回具名错误或在开发/CI fail-fast，禁止静默默认假数据。
9. **删除胜过兼容。** 本轮无旧存档兼容要求；仓库调用迁完后立即删除旧 API、fallback 和转发。
10. **测试可复用。** 测试通过公共命令、query 和 contract 驱动，不绑定私有函数与临时目录结构。

## 4. 最终运行时架构

```text
AppRoot（唯一 main_scene，常驻）
├── SceneHost                 当前唯一可导航 Page/Game Scene
├── ModalLayer / ModalHost    阻塞弹窗
├── TransientLayer            Toast、Tooltip、Item Popup、GM
├── TransitionLayer           加载遮罩和重复导航阻断
└── Feature Roots             Story/Tutorial 等长于页面但非全局基础设施的节点

Autoload（最终仅 3 个）
├── DataStore                 长期状态和 session 值的唯一容器
├── ConfigCatalog             原样 JSON 的只读、按需查询入口
└── SceneManager              路由、payload、场景原子替换
```

### 4.1 AppRoot

- `AppRoot` 成为唯一 `main_scene`，组合固定 Host 并完成启动检查。
- Overlay、GM、剧情和教程不得成为 Autoload；由 `AppRoot` 或所属功能场景持有。
- 页面离开默认释放，不缓存隐藏页面。
- 全局 CanvasLayer 层级只在 `app_root.tscn` 定义。

### 4.2 Autoload

最终只保留：

| 名称 | 唯一职责 |
| --- | --- |
| `DataStore` | 持有已校验的长期状态和可恢复 session；不含业务算法和文件 I/O |
| `ConfigCatalog` | 按需读取单个导出 JSON，校验并提供只读查询 |
| `SceneManager` | 路由注册、payload 校验、过渡锁、返回栈和场景原子替换 |

`GameState`、`LilianState`、`SaveService`、`DataEvents`、各 UI Host、`StoryDirector`、`TutorialService` 均为迁移对象，不是最终 Autoload。

### 4.3 模块化单体

```text
scripts/
├── app/                     AppRoot 启动与组合
├── core/
│   ├── state/               DataStore、全新存档 schema
│   ├── config/              通用 JSON reader、ConfigCatalog
│   ├── navigation/          SceneManager、route/payload
│   └── contracts/           真正跨模块的稳定数据契约
├── features/
│   ├── character/           创建、属性、境界
│   ├── inventory/           背包、物品、装备、负重
│   ├── cultivation/         已有修炼行为
│   ├── alchemy/             已有炼丹行为
│   ├── breakthrough/        已有突破行为
│   ├── commission/          已有委托行为
│   ├── world_map/           地图与旅行
│   ├── lilian/              历练 session、事件、结算
│   ├── battle/              战斗、主动/被动技能、Buff、AI
│   ├── story/               当前已完成部分
│   ├── tutorial/            当前已完成部分
│   ├── gongfa/               现有功法、装备、熟练度与效果
│   └── dao_design/           界面与设计占位，不实现玩法
└── ui/shared/               无业务规则的共享 View/Host
```

实际目录迁移必须按阶段逐步完成；禁止先创建空目录和空层。文件名继续遵守项目角色后缀，不新增 `manager/helper/utils/common` 万能脚本。

### 4.4 模块内最小分层

仅在真实职责存在时创建：

```text
presentation  页面、Panel、Dialog、View
      ↓ intent / snapshot
application   用例编排、跨状态切片的原子提交
      ↓
domain        纯规则、不变量、确定性计算
      ↓ query
catalog       本模块原始 JSON 查询函数
```

- 简单模块可以只有 application + view，不强制四层齐全。
- Catalog 不转换成第二套数据模型，不执行伤害、奖励、价格等玩法计算。
- Domain 不依赖 Node、SceneTree、Autoload、FileAccess 或 UI。
- Application 是唯一允许协调多个状态切片和触发自动存档的层。

## 5. 配置与 Excel 边界

### 5.1 数据链

```text
C:\godot\excel_config\indir\*.xlsx
        ↓ 通用导出器：原样、确定性
data/exportjson/**/*.json
        ↓ JsonReader + 对应模块薄查询函数
Application / Domain
```

- Godot 运行时只读取导出的 JSON，不读取 `.xlsx`。
- 导出阶段禁止添加针对具体业务表的特殊转换代码。
- 不生成规范化中间 JSON，不建立通用 Definition/DTO 映射层。
- 查询封装只负责：按 ID/类型查找、必填字段与引用校验、返回只读深拷贝。
- 业务公式、效果解释和状态修改留在对应 Domain/Application。
- UI 不直接打开 JSON 或调用 FileAccess。

### 5.2 禁止修改的 Excel

以下文件的工作表、列名和数据值均视为不可修改外部输入：

- `effects效果介绍.xlsx`
- `道具.xlsx`
- `怪物.xlsx`
- `技能表_战斗被动buff配置.xlsx`
- `境界.xlsx`
- `新建角色.xlsx`

这六张表只能原样导出并由代码按原字段查询。其他 Excel 允许为了结构一致性进行拆表、合表、字段命名和引用规范化，但不得借重构修改玩法数值。

### 5.3 配置验收

- 每张运行时表必须有 schema/reference validator。
- 缺文件、重复 ID、必填字段缺失、类型错误、失效引用必须失败。
- Validator 读取与游戏相同的导出 JSON，不复制整份生产数据为 fixture。
- 功法 validator 保护现有玩法数据；大道 validator 保留以保护未来设计数据，通过不代表本轮实现大道玩法。

## 6. 状态、存档与设置

### 6.1 状态分类

| 类型 | 所有者 | 是否持久化 |
| --- | --- | --- |
| 静态配置 | `ConfigCatalog` | 随构建发布，不进存档 |
| 玩家长期状态 | `DataStore` | 是 |
| 历练/战斗 session | 对应 Application 提交到 `DataStore` 的可恢复值 | 按恢复需求 |
| Scene payload | `SceneManager` | 消费即删，默认不持久化 |
| UI 临时状态 | 所属 View/Page | 否 |
| 设置 | `SettingsRepository` | 独立 `settings.json` |

`DataStore` 不公开内部可变 Dictionary。Query 返回深拷贝快照；Command 通过 Application 校验后一次提交新状态。

### 6.2 唯一自动存档

- 不提供存档/读档页面和手动存档槽。
- 主菜单只提供“新游戏”和“继续游戏”。
- 每次关键业务结算成功后，由 Application 统一请求自动存档；失败的操作不得落盘半成品。
- `continue` 自动读取唯一存档；主文件损坏时尝试备份，仍失败则明确提示并只允许新游戏。
- 新游戏覆盖已有存档前必须明确确认。

存档路径：

```text
user://saves/
├── autosave.json
├── autosave.bak
└── autosave.tmp
```

写入顺序：状态深拷贝与校验 → 写临时文件 → 关闭并重读校验 → 保留备份 → 原子替换。任一步失败必须保留旧存档。

全新 schema 不提供旧版本 migration；但必须保留 `schema_version`，未来出现第二版时再增加连续 migration。

### 6.3 设置

`user://settings.json` 独立保存音量、分辨率和显示模式。新游戏、删除存档或存档损坏不得清除设置。

## 7. 导航、UI 与输入

### 7.1 导航

- 所有 Page/Game Scene 使用唯一 route 表登记。
- SceneManager 只做导航，不执行历练开始、结算、奖励、教程或战斗数据装配。
- 导航前校验 route/payload；新场景成功实例化并加入 `SceneHost` 后才释放旧场景。
- 失败时旧场景保持可用；空闲时 `SceneHost` 只有一个活动可导航场景。
- 战斗叠层、背包和 Dialog 的生命周期由明确 Host 管理，不在 SceneManager 混入业务判断。

### 7.2 UI

- 保留现有视觉和主要交互结果。
- 固定 UI、布局、Theme 和静态资源写在 `.tscn`；脚本仅做绑定、局部状态、信号和动画。
- 动态数量列表项使用独立子场景实例化；地图连线、战斗浮字等天然动态节点可以代码创建。
- UI 只调用 Application command/query；禁止引用 `DataStore`、FileAccess 或原始 JSON。
- UI 不计算伤害、价格、奖励、成功率或配置归一化。
- 固定节点使用 `unique_name_in_owner = true` 和 `%NodeName`。

### 7.3 输入与显示

- GUI 使用 Control signal；快捷键使用 InputMap。
- 本轮只验收键盘鼠标，不建设手柄抽象层。
- 设计分辨率与显示模式由独立设置用例管理，不由各页面自行修改窗口。

## 8. Contract 与结果模型

只在以下边界建立 typed contract：

- route payload；
- 战斗输入与战斗总结；
- 历练结算；
- 自动存档 schema；
- 跨功能奖励、库存扣除和时间推进；
- UI 需要稳定只读结构的复杂快照。

结果按用途保持最小：

```text
CommandResult: ok, error_code?, message?, changed_snapshot?
QueryResult:   ok, error_code?, value?
Navigation:    ok, error_code?, route_id?
```

只有真实需要时才增加 events 或 payload。禁止统一六字段万能 Result、万能基类和每函数一个 DTO。

## 9. 测试与单一门禁

### 9.1 测试分层

| 测试 | 覆盖 | 复用原则 |
| --- | --- | --- |
| Unit | Domain 纯规则、边界、seed 确定性 | 通过公开函数，不绑定 Node 和 Autoload |
| Contract | 原样 JSON、route payload、战斗/历练结果、存档 schema | fixture 只含最小行 |
| Integration | Application + DataStore + 查询封装，成功提交与失败回滚 | 使用内存状态和测试 `user://` |
| Smoke | AppRoot 启动、全部 route 实例化、关键主链路 | 统一 headless runner |

- 新增或修改非平凡逻辑必须留下一个最小可运行检查。
- 随机系统注入 seed，时间逻辑注入时间值。
- 测试不得读写真实玩家存档。
- UI 不做像素级单元测试；通过 scene smoke 和关键交互链验证。

### 9.2 唯一命令

最终本地和 CI 只运行：

```text
npm run validate
```

该命令必须依次覆盖：

1. 全部配置 schema/reference validator。
2. 架构依赖和 DataStore/UI 禁止项。
3. 孤立 UID、缺失脚本、资源引用和 route 表。
4. Godot unit/contract/integration tests。
5. 全部 route scene smoke。
6. Godot headless 启动，输出不得包含 ERROR。
7. `git diff --check`。

任一步失败返回非零退出码。Windows PowerShell 执行策略问题不能改变标准入口；需要用 Node/PowerShell 包装在 `npm run validate` 内解决。

## 10. AI 执行协议

每个阶段开始前，AI 必须：

1. 重新读取 `AGENTS.md`、生产规范和本文。
2. 检查工作区与最近提交，禁止覆盖用户未提交改动。
3. 扫描本阶段真实调用链，列出 public API、状态写点、route、配置和资源引用。
4. 输出本阶段计划文件、行为基线、迁移影响和最小验收命令。
5. 先补能保护现有行为的最小测试，再改实现。

每个阶段结束前，AI 必须：

1. 删除本阶段已无调用的旧入口和 fallback。
2. 运行本阶段测试以及当前完整 `npm run validate`。
3. 汇总全部修改文件、行为是否等价、剩余风险和下一阶段入口条件。
4. 保持提交单一目的；目录移动与业务逻辑修改不得混在同一提交。

AI 只有在以下情况暂停询问用户：

- 将改变玩法结果或玩家可见的主要交互结果；
- 将删除当前已完成且可用的功能；
- 将修改六个受保护 Excel 的结构或值；
- 同一验收阻塞经根因修复仍无法解除；
- 需要扩大到 Steamworks、性能专项或新功能。

其他内部命名、目录、模块拆分和私有 API 调整由 AI 按生产规范自行决定。

## 11. 实施阶段

### Phase 0：冻结并刻画真实产品

状态：2026-07-12 已完成，`npm run validate` 全绿，分类已确认。

目标：得到可信的“已完成/仅设计”清单和绿色重构基线。

- 自动扫描所有 route、场景入口、Autoload、配置表、状态写点和跨模块调用。
- 运行并人工抽查关键链路，把功能分为：已完成必须保留、仅界面/设计、失效死代码。
- 生成分类清单供用户一次确认；大道和自主研读/知识成长归入“仅设计”，技能与功法归入“必须保留”。
- 删除 `character_creation.json` 运行时依赖，保留姓名 1–12 字符规则。
- 对齐技能和道具效果注册表，修复当前 33 + 34 项验证失败，不修改受保护 Excel。
- 删除确认无源的 4 个孤立 UID。
- 扩充 `npm run validate` 到至少包含当前配置、UID/资源和 Godot 启动检查。
- 为已完成主链建立 characterization tests。

退出条件：当前配置与资源检查全绿；Godot headless 无 ERROR；分类清单获确认；主要可玩链路有最小保护。

### Phase 1：建立 AppRoot、导航和配置边界

- 建立 `AppRoot` 与静态 Host 组合，切换唯一 main scene。
- SceneManager 只保留 route/payload/场景生命周期，迁出历练、战斗、教程和状态判断。
- 把 13 个 Autoload 分批收敛到目标 3 个；本阶段先迁 UI Host 和剧情/教程生命周期。
- 将 `JsonLoader` 缩为通用 reader，将 `ConfigManager` 缩为按模块原表查询入口；不创建中间数据层。
- 建立 core 不依赖 feature、UI 不引用 DataStore/FileAccess 的静态门禁。

退出条件：AppRoot 启动；route 原子切换；core 反向依赖为 0；配置按需读取单个 JSON；行为测试保持通过。

### Phase 2：重建状态、单自动存档和设置

- 盘点所有 `savedata/rundata` 字段和写入点，为每个字段指定唯一 Application 所有者。
- 建立全新 DataStore schema，不保留旧字段兼容。
- 建立 command/query 提交边界，移除 UI 和 service 对可变字典的直接访问。
- 实现唯一自动存档的临时文件、重读校验、备份和原子替换。
- 实现独立 settings repository 和三种显示模式。
- 重做主菜单为新游戏/继续游戏流程，不建设存档页面。

退出条件：状态写点只有 Application；新建、自动保存、继续、备份恢复和设置持久化测试全绿。

### Phase 3：迁移长期玩法垂直切片

按真实依赖从低风险到高风险逐个迁移，每次只迁一个可验收用例组：

1. 角色创建与角色查询。
2. 时间推进。
3. 背包、物品、装备与负重。
4. 修炼。
5. 炼丹。
6. 突破。
7. 地图旅行与委托。

每个切片都必须完成：Catalog 薄查询 → Domain 纯规则 → Application command/query → UI 快照/意图 → 自动存档 → 测试 → 删除旧实现。

功法随修炼切片保留选择、装备、熟练度和现有效果；大道、自主研读和其他“仅设计”功能只整理界面边界与未来模块说明，不创建玩法实现。

退出条件：`GameState` 不再承担业务和全局状态代理；完成模块无 UI 直写状态；所有切片行为检查通过。

### Phase 4：历练、战斗与技能

- 把历练改为可序列化 session + Application，用明确 command 推进事件、地图、战斗衔接和结算。
- 战斗只接受 validated BattleInit，只返回 BattleSummary；不得读取 GameState/LilianState。
- 战斗 Domain 在无 SceneTree、无 Autoload 下完成一次确定性模拟。
- 保留并重构主动技能、被动技能、Buff、目标选择、释放策略和物品战斗效果。
- 删除运行时 fallback builder；配置无效时拒绝进入战斗并返回明确错误。
- UI/VFX 只消费战斗快照和事件，不成为规则所有者。

退出条件：历练—战斗—返回/结算链行为等价；同 seed 结果确定；战斗和技能 unit/contract/integration tests 全绿。

### Phase 5：UI、剧情、教程与全局清理

- 将固定 UI 迁回 `.tscn`，保留视觉和主要交互行为。
- 页面统一使用 Application API；共享 View 禁止访问 Autoload。
- 剧情、教程只通过公开事件/query/command 工作，不直接写 DataStore。
- 合并 Overlay 生命周期到 AppRoot Host。
- 删除 DataEvents 的无策略转发、旧 Host、旧门面、孤立脚本、兼容字段和失效 enum。
- 完成 3 Autoload 目标和完整静态架构门禁。

退出条件：presentation 无 DataStore/FileAccess/业务计算；13 个 Autoload 收敛为 3 个；旧入口调用为 0。

### Phase 6：生产验收

- 执行全部 unit、contract、integration、route smoke 和 headless 启动。
- 验收 Windows 键鼠下 `1920×1080`、`1280×720` 与三种显示模式。
- 验收主链：启动 → 新建角色 → 洞府 → 修炼/炼丹/突破 → 背包/装备 → 地图/委托 → 历练 → 战斗/技能 → 结算 → 自动存档 → 重启继续。
- 验收当前已完成的剧情、教程及 Phase 0 分类清单中的全部保留功能。
- 确认功法玩法保持可用；大道、自主研读和其他未完成功能只保留界面与设计，没有伪实现。
- 运行导出构建 smoke；Steamworks 集成不在本轮范围。

退出条件：`npm run validate` 全绿；Windows 导出可启动；无 ERROR、孤立资源、旧兼容或未登记状态写点。

## 12. 最终完成定义

只有同时满足以下条件才可宣告重构完成：

1. 已完成玩法与主要界面行为通过 Phase 0 基线和最终主链验收。
2. 技能与功法系统完整保留；大道、自主研读和其他未完成系统仅保留界面和设计。
3. 最终只有 `DataStore`、`ConfigCatalog`、`SceneManager` 三个 Autoload。
4. UI 不直接访问状态、文件或原始配置；业务状态只有 Application 可提交。
5. Domain 可脱离 SceneTree、Node 和 Autoload 测试。
6. 运行时只读取 Excel 原样导出的单个 JSON；无第二套中间配置。
7. 六个受保护 Excel 未被修改；其他表只有结构治理，没有数值平衡变更。
8. 唯一自动存档、备份恢复和独立设置可用；没有旧存档兼容代码。
9. 所有 route、payload、资源、UID、配置引用和架构边界由 `npm run validate` 自动检查。
10. 没有迁移门面、静默 fallback、无调用 API、万能 DTO 或为未来预建的空抽象。
11. Windows 键鼠和目标分辨率/显示模式验收通过。
12. 修改记录、测试结果和剩余的“仅设计”功能边界清晰，可由后续 AI 继续执行。
