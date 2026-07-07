# 修仙历练项目管理总览

## 项目定位

项目是 Godot 4.6 的修仙题材放置 / 卡牌 RPG，当前主入口为 `res://scenes/ui/main_menu.tscn`。核心体验围绕洞府成长、世界地图、历练事件、自动战斗、功法技能、炼丹、突破、新手剧情和背包装备展开。

## 已确认技术边界

- 引擎：Godot 4.6，GL Compatibility，窗口基准 `1280x800`。
- 入口：`project.godot` 指向 `scenes/ui/main_menu.tscn`。
- 运行状态：统一经 `DataStore` / `GameState` / `LilianState` 等 Autoload 管理。
- 配置数据：主数据在 `xiuxian配置表` 导出到 `data/exportjson/*.json`。
- 场景组织：全屏 / 可导航场景登记在 `SceneManager.SCENE_PATHS`；复用 UI 优先拆成 `.tscn` 子场景。
- 枚举：离散类型集中在 `scripts/enum/enum_*.gd`，通过 `class_name` 访问。
- 测试：使用 `tests/run_tests.ps1` 和 `tests/run_all_tests.ps1` 运行 headless Godot 测试。

## 当前模块盘点

| 模块 | 现状 | 主要文件 |
| --- | --- | --- |
| 核心状态与配置 | 已有统一存档、运行时、配置加载和校验入口 | `scripts/core`, `scripts/sim/game_state.gd`, `scripts/core/config_manager.gd` |
| 场景导航 | 已有集中式 SceneManager，并支持历练中的战斗 / 面板浮层 | `scripts/core/scene_manager.gd` |
| 洞府与成长 | 已有修炼、属性、突破、炼丹、背包、功法面板 | `scenes/sim`, `scripts/sim`, `scenes/ui` |
| 历练 | 已有地图节点、事件、战斗接入、结算和日志 | `scenes/lilian`, `scripts/lilian`, `docs/lilian-system.md` |
| 战斗 | 已有战斗域、AI、VFX、浮字、战报、结果浮层 | `scenes/zhandou`, `scripts/zhandou` |
| 世界地图 | 已有城市、野外区域、地点详情、旅行确认 | `scenes/map`, `scripts/map`, `docs/world-map-module-design.md` |
| 大道 / 功法 / 技能 | 已有知识树、功法、技能、自动战斗配置 | `scripts/dao`, `data/exportjson/dao_tree*.json`, `data/exportjson/jineng*.json` |
| 剧情 / 新手引导 | 已有剧情播放、引导遮罩、教程服务和配置 | `scripts/story`, `scenes/story`, `data/exportjson/gushi_*.json` |
| UI 提示 | 已有 Tips、HoverTip、道具详情等可复用浮层 | `scripts/ui/tips`, `scripts/ui/hover`, `scenes/ui` |

## 管理原则

- 先稳纵切片，再扩内容量。
- 每个开发任务控制在 30-60 分钟可验收。
- 新增 UI 固定布局写 `.tscn`，脚本只做数据绑定、状态切换、信号处理。
- 新增跨场景 / 跨存档状态先改 `DataStore` 默认值和兼容合并。
- 新增可导航场景必须登记 `SceneManager.SCENE_PATHS`。
- 新增配置必须补配置校验或现有 headless 测试覆盖。

## 当前优先风险

1. P4 的主要痛点是早期体验：战败恢复、基础材料不足、学习功法 / 技能路径不清。
2. P3 新内容已过自动回归，但缺少图形化长时手动游玩，体感问题要在 P4 暴露并修掉。
3. 数据配置增长快，必须继续把配置校验当作内容生产门槛。
4. UI 场景数量多，后续新增界面要复用组件，避免同类按钮、行组件、弹窗重复造。
## 近期目标

当前阶段是 P4 体验修正与打磨，不扩新系统、不投放新区域，先让新局到筑基前的路线舒服一点。

优先顺序：

- 战败后看得懂损失和恢复路径，休息 / 炼丹 / 研读 / 技能配置能形成下一步。
- 早期短历练能稳定带回基础炼丹材料，至少支撑一炉基础丹药。
- 功法和技能学习不新增系统，先把典籍掉落、研读入口、技能配置入口讲清楚。
- 小操作问题只收 30-60 分钟内能修的项，超过就移出 P4。

P4 验收以 `run_config_validation_tests.gd`、`run_lilian_tests.gd`、`run_balance_v1_tests.gd` 通过，加一轮短手动路线确认普通战不卡死、失败后能恢复为准。
