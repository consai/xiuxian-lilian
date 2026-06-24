# 项目任务看板

## 已完成：P0 可玩闭环稳定版

完成标准：完整 headless 测试通过，手动验收清单已建立。

### [x] PM-001：确认历练浮层链路

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

### [x] PM-002：补齐历练背包验收

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

### [x] PM-003：跑通场景导航回归

描述：覆盖主菜单、洞府、世界地图、历练、战斗、结算、背包、功法策略这些可导航场景。

验收：

- `tests/run_scene_manager_tests.gd` 通过。
- 所有全屏 / 面板入口通过 `SceneManager` helper 进入。
- 没有业务脚本直接 `change_scene_to_file` 到可导航场景。

涉及文件：

- `scripts/core/scene_manager.gd`
- `tests/run_scene_manager_tests.gd`

### [x] PM-004：配置校验做 P0 门禁

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

## 已完成：P1 新手体验

验收记录：

- `tests/run_story_tests.gd` 通过。
- `tests/run_scene_manager_tests.gd` 通过。
- `tests/run_expedition_tests.gd` 的 P1 教程路线图、首战绑定、奖励结算相关用例通过；整套测试仍有强制节点类型的旧假设失败，另行修。

### [x] PM-101：新局教程状态审计

描述：确认新局、旧档、跳过教程三种情况下 `tutorial` 存档字段正确。

验收：

- 新局进入 T00。
- 旧存档不会被强制进入教程。
- 跳过后关键入口可用。

涉及文件：

- `scripts/core/data_store.gd`
- `scripts/story/tutorial_service.gd`
- `data/stories/prologue_tutorial.yaml`

### [x] PM-102：第一场战斗奖励闭环

描述：把教程路线图历练、第一场战斗、奖励、背包查看、关闭背包和后续炼丹入口串起来。

验收：

- 引导适配路线图历练，不依赖旧事件卡固定出现。
- 首战胜利触发教程事件。
- 奖励进入背包或结算摘要。
- 查看背包奖励后先引导关闭背包，再引导丹炉。
- 引导下一步不依赖隐藏状态。

涉及文件：

- `scripts/expedition/expedition_state.gd`
- `scripts/story/story_director.gd`
- `scripts/story/tutorial_service.gd`

### [x] PM-103：首批正式人物表现

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

### [x] PM-104：洞府改为小道观

描述：把当前洞府主场景的设定与视觉方向调整为山间小道观，先改首屏气质，不扩新玩法。

验收：

- 主界面背景从洞府室内感改为小道观 / 山风 / 晨光 / 炉烟气质。
- 洞府相关按钮和文案不再与新设定冲突。
- 新手剧情开场能解释玩家为何在小道观醒来并开始早课。
- 不改变现有成长、背包、炼丹、历练入口逻辑。

涉及文件：

- `scenes/sim/cave_hub.tscn`
- `scripts/sim/cave_hub.gd`
- `assets/art`
- `data/stories/prologue_tutorial.yaml`

## 当前冲刺：P2 数值与内容校准

目标：练气到筑基前的成长、资源、战斗难度可测；先把现有内容调稳，不扩高阶境界。

P2 通过标准：

- `tests/run_balance_v1_tests.gd`、`tests/run_config_validation_tests.gd`、`tests/run_expedition_tests.gd` 通过。
- 30-60 分钟手动游玩能看到修炼、历练、炼丹、突破预览四条短期目标。
- 同境界普通战斗不秒杀、不拖沓；精英战有失败风险但不是纯看运气。
- 筑基前资源不会必然卡死，也不会无限膨胀。

### [x] PM-201：平衡基准复核

描述：把当前 `realm_balance.yaml` 的练气初期、练气成型、筑基初期基准和自动测试结果对齐，先确认目标线，不急着调内容。

验收：

- `run_balance_v1_tests.gd` 输出记录到任务备注或数值文档。
- 普通敌胜率、普通战时长、精英胜率、跨境界压制都在 acceptance 范围内。
- 如需调参，只改 `data/realm_balance.yaml` 或直接相关配置，不做新平衡系统。

涉及文件：

- `data/realm_balance.yaml`
- `tests/run_balance_v1_tests.gd`
- `docs/realm-balance-foundation.md`

任务备注：

- 2026-06-24：`run_balance_v1_tests.gd` 通过；普通敌胜率 0.800、普通战时长 8.72 秒、精英胜率 0.425、练气成型对筑基普通胜率 0.050，均在 acceptance 范围内。

### [x] PM-202：练气期怪物与事件强度校准

描述：校准青岚山脉、野狼谷、黑水沼泽的普通 / 精英 / Boss 遭遇，确保难度带能读懂。

验收：

- 普通战可作为稳定资源获取。
- 精英战需要准备丹药或技能配置。
- Boss 战作为阶段检查点，不要求新手裸打稳定通过。
- 怪物属性、技能槽、掉落池都通过配置校验。

涉及文件：

- `data/monsters.yaml`
- `data/locations.yaml`
- `data/expedition_events.yaml`
- `tests/run_expedition_tests.gd`

任务备注：

- 2026-06-24：青岚山脉、野狼谷、黑水沼泽均接入普通 / 精英 / Boss 遭遇；Boss 事件改为高难度检查点。`run_config_validation_tests.gd` 与 `run_expedition_tests.gd` 通过。

### [x] PM-203：筑基前资源循环校准

描述：检查修炼、历练奖励、炼丹消耗、丹药产出、突破准备之间的资源节奏。

验收：

- 历练能稳定产出基础炼丹材料。
- 炼丹不会因材料过少变成摆设，也不会无限放大收益。
- 修炼丹药能明显加速，但会保留灵力驳杂或机会成本。
- 破境准备需要多次活动积累，而不是一次历练直接完成。

涉及文件：

- `data/item.yaml`
- `data/alchemy.yaml`
- `data/expedition_rules.yaml`
- `data/breakthrough_rules.yaml`
- `scripts/sim/alchemy_service.gd`
- `scripts/sim/breakthrough_service.gd`

任务备注：

- 2026-06-24：聚气丹方难度从 45 调整为 38；新手稳火炼制成功率约 0.53，妖丹仍限制批量放大。新增资源闭环回归：历练材料可炼聚气丹，丹药修炼显著加速并产生灵力驳杂，筑基预览仍需要多次活动积累。`run_simulation_tests.gd` 与 `run_config_validation_tests.gd` 通过。

### [x] PM-204：功法 / 技能首版池收敛

描述：只保留练气到筑基前真正会用到的功法、技能、知识效果，补齐缺口，暂不扩高阶流派。

验收：

- 新手默认技能组能应对普通历练。
- 至少有 2 种可理解的战斗倾向：稳健 / 输出。
- 技能知识成长能在 UI 和战斗结果中被感知。
- 同层技能强度差异控制在 `realm_balance.yaml` budgets 附近。

涉及文件：

- `data/abilities.yaml`
- `data/cultivation_methods.yaml`
- `data/knowledge_effects.yaml`
- `data/dao_tree.yaml`
- `tests/run_dao_knowledge_tests.gd`

任务备注：

- 2026-06-24：新手默认技能组保持御气弹 / 流风步 / 破空剑气，补齐输出与防御标签；破空剑气基准伤害从 55 收敛到 54，使练气同阶伤害贴近 `realm_balance.yaml` 预算。新增练气知识效果与 PM-204 回归，知识成长会影响运行时技能数值和派生属性。`validate-abilities.mjs`、`validate-cultivation-methods.mjs`、`run_dao_knowledge_tests.gd`、`run_config_validation_tests.gd`、`run_battle_domain_tests.gd`、`run_simulation_tests.gd`、`run_balance_v1_tests.gd` 通过。

### [x] PM-205：突破前目标可读性

描述：让玩家在筑基前知道自己差什么，不做复杂新面板，只补现有突破 / 角色 / 活动反馈。

验收：

- 突破面板能看懂当前分项、总分、品质档、主要缺口。
- 炼丹、修炼、历练至少各有一条能帮助突破的明确反馈。
- 失败 / 未满足条件提示不只说“不能突破”。

涉及文件：

- `scenes/sim/breakthrough_summary.tscn`
- `scripts/sim/breakthrough_summary.gd`
- `data/breakthrough_rules.yaml`
- `docs/breakthrough-system.md`

任务备注：

- 2026-06-24：突破页增加主要缺口提示，区分总分不足、下一品质差距与知识点门槛；修炼、炼丹、历练结果各补一条突破准备反馈。新增 `run_pm205_breakthrough_feedback_tests.gd` 覆盖缺口文案。

### [ ] PM-206：战斗特效体验版

描述：在战斗节奏和数值稳定后，按技能类型补清晰特效。

验收：

- 普攻、弹道、护盾、治疗、持续伤害有不同反馈。
- 特效不遮挡血条、行动条、战斗日志。
- 低配表现可关闭或降级。

涉及文件：

- `scripts/fight/vfx`
- `scripts/fight/fight_vfx_manager.gd`
- `data/combat/presets`

### [ ] PM-207：P2 手动游玩验收

描述：做一次 30-60 分钟筑基前游玩记录，验证目标、资源和战斗手感。

验收：

- 记录从新局到第一次突破预览的关键节点。
- 记录普通战、精英战、炼丹、修炼丹药使用后的体感问题。
- 只列 P2 必修问题；纯内容扩展放 P3。

产物：

- `docs/project-management/p2-playtest-notes.md`

## 暂缓任务

- 高阶境界完整投放：P2 前不做。
- 新地图大批量内容：P0 稳定后再批量加。
- 新 UI 框架或管理插件：现有 Godot 场景和 Markdown 文档够用。
