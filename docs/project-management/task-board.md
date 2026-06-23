# 项目任务看板

## 当前冲刺：P0 可玩闭环稳定版

### [ ] PM-001：确认历练浮层链路

描述：核对历练中进入战斗、胜利返回、战败结算、打开背包 / 技能策略面板的状态变化。

验收：

- 历练战斗通过 `SceneManager.go_fight(..., "expedition")` 进入浮层。
- 胜利后恢复原历练界面，不重建历练状态。
- 战败 / 撤退进入历练结算。
- 背包 / 策略面板关闭后恢复历练界面。

涉及文件：

- `scripts/core/scene_manager.gd`
- `scripts/expedition/expedition_battle_flow.gd`
- `scripts/expedition/expedition_loop.gd`
- `scripts/ui/backpack_panel.gd`

### [ ] PM-002：补齐历练背包验收

描述：确认历练运行时背包只改 `DataStore.expedition_runtime()`，结算后再投影回存档。

验收：

- 历练中使用丹药只扣 runtime 库存。
- 战斗中不可通过历练背包绕过限制。
- 结算后剩余槽位物品和奖励合并正确。
- 失败丢失规则按配置生效。

涉及文件：

- `scripts/expedition/expedition_state.gd`
- `scripts/expedition/expedition_reward_service.gd`
- `tests/run_expedition_tests.gd`

### [ ] PM-003：跑通场景导航回归

描述：覆盖主菜单、洞府、世界地图、历练、战斗、结算、背包、功法策略这些可导航场景。

验收：

- `tests/run_scene_manager_tests.gd` 通过。
- 所有全屏 / 面板入口通过 `SceneManager` helper 进入。
- 没有业务脚本直接 `change_scene_to_file` 到可导航场景。

涉及文件：

- `scripts/core/scene_manager.gd`
- `tests/run_scene_manager_tests.gd`

### [ ] PM-004：配置校验做 P0 门禁

描述：把 P0 涉及配置表的缺字段、非法引用、奖励 ID、怪物 ID 检查保持在测试里。

验收：

- `tests/run_config_validation_tests.gd` 通过。
- `data/locations.yaml`、`data/expedition_events.yaml`、`data/monsters.yaml`、`data/item.yaml` 的 P0 引用无错误。
- 新增配置不需要手动进游戏才发现坏引用。

涉及文件：

- `scripts/core/config_validator.gd`
- `tests/run_config_validation_tests.gd`
- `data/*.yaml`

### [x] PM-005：手动游玩脚本

描述：写一条短手动验收路径，用于每次 P0 改动后照着点。

验收：

- 文档列出新局到结算的点击路径。
- 记录预期 UI 反馈和失败时截图位置。
- 20 分钟内可执行完。

产物：

- `docs/project-management/playtest-checklist.md`

## 下一冲刺：P1 新手体验

### [ ] PM-101：新局教程状态审计

描述：确认新局、旧档、跳过教程三种情况下 `tutorial` 存档字段正确。

验收：

- 新局进入 T00。
- 旧存档不会被强制进入教程。
- 跳过后关键入口可用。

涉及文件：

- `scripts/core/data_store.gd`
- `scripts/story/tutorial_service.gd`
- `data/stories/prologue_tutorial.yaml`

### [ ] PM-102：第一场战斗奖励闭环

描述：把教程第一场战斗、奖励、背包查看和后续修炼入口串起来。

验收：

- 首战胜利触发教程事件。
- 奖励进入背包或结算摘要。
- 引导下一步不依赖隐藏状态。

涉及文件：

- `scripts/expedition/expedition_state.gd`
- `scripts/story/story_director.gd`
- `scripts/story/tutorial_service.gd`

### [ ] PM-103：首批正式人物表现

描述：替换新手流程最常见的角色表现，不做全角色美术库。

验收：

- 主角默认形象可用于角色面板和战斗。
- 新手引导相关角色有头像 / 立绘占位。
- 首战敌人有可识别头像或战斗图。
- 不影响存档字段和战斗结算。

涉及文件：

- `assets/art`
- `scenes/story`
- `scenes/fightScene.tscn`

### [ ] PM-104：洞府改为山顶清修地

描述：把当前洞府主场景的设定与视觉方向调整为山顶清修地，先改首屏气质，不扩新玩法。

验收：

- 主界面背景从洞府室内感改为山顶 / 云海 / 清修地气质。
- 洞府相关按钮和文案不再与新设定冲突。
- 新手剧情开场能解释玩家为何在清修地醒来或停留。
- 不改变现有成长、背包、炼丹、历练入口逻辑。

涉及文件：

- `scenes/sim/cave_hub.tscn`
- `scripts/sim/cave_hub.gd`
- `assets/art`
- `data/stories/prologue_tutorial.yaml`

## P2 表现升级

### [ ] PM-201：战斗特效体验版

描述：在战斗节奏和数值稳定后，按技能类型补清晰特效。

验收：

- 普攻、弹道、护盾、治疗、持续伤害有不同反馈。
- 特效不遮挡血条、行动条、战斗日志。
- 低配表现可关闭或降级。

涉及文件：

- `scripts/fight/vfx`
- `scripts/fight/fight_vfx_manager.gd`
- `data/combat/presets`

## 暂缓任务

- 高阶境界完整投放：P2 前不做。
- 新地图大批量内容：P0 稳定后再批量加。
- 新 UI 框架或管理插件：现有 Godot 场景和 Markdown 文档够用。
