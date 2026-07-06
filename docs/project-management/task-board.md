# 项目任务看板

## 已完成：P0 可玩闭环稳定版

完成标准：完整 headless 测试通过，手动验收清单已建立。

### [x] PM-001：确认历练浮层链路

描述：核对历练中进入战斗、胜利返回、战败结算、打开背包 / 技能策略面板的状态变化。

验收：

- 历练战斗通过 `SceneManager.go_zhandou(..., "expedition")` 进入浮层。
- 胜利后恢复原历练界面，不重建历练状态。
- 战败 / 撤退进入历练结算。
- 背包 / 策略面板关闭后恢复历练界面。

涉及文件：

- `scripts/core/scene_manager.gd`
- `scripts/lilian/lilian_battle_flow.gd`
- `scripts/lilian/expedition_loop.gd`
- `scripts/ui/beibao_panel.gd`

### [x] PM-002：补齐历练背包验收

描述：确认历练运行时背包只改 `DataStore.lilian_runtime()`，结算后再投影回存档。

验收：

- 历练中使用丹药只扣 runtime 库存。
- 战斗中不可通过历练背包绕过限制。
- 结算后剩余槽位物品和奖励合并正确。
- 失败丢失规则按配置生效。

涉及文件：

- `scripts/lilian/lilian_state.gd`
- `scripts/lilian/lilian_reward_service.gd`
- `tests/run_lilian_tests.gd`

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
- `data/didian.yaml`、`data/lilian_events.yaml`、`data/guaiwu.yaml`、`data/item.yaml` 的 P0 引用无错误。
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
- `tests/run_lilian_tests.gd` 的 P1 教程路线图、首战绑定、奖励结算相关用例通过；整套测试仍有强制节点类型的旧假设失败，另行修。

### [x] PM-101：新局教程状态审计

描述：确认新局、旧档、跳过教程三种情况下 `tutorial` 存档字段正确。

验收：

- 新局进入 T00。
- 旧存档不会被强制进入教程。
- 跳过后关键入口可用。

涉及文件：

- `scripts/core/data_store.gd`
- `scripts/story/tutorial_service.gd`
- `data/gushi/prologue_tutorial.yaml`

### [x] PM-102：第一场战斗奖励闭环

描述：把教程路线图历练、第一场战斗、奖励、背包查看、关闭背包和后续炼丹入口串起来。

验收：

- 引导适配路线图历练，不依赖旧事件卡固定出现。
- 首战胜利触发教程事件。
- 奖励进入背包或结算摘要。
- 查看背包奖励后先引导关闭背包，再引导丹炉。
- 引导下一步不依赖隐藏状态。

涉及文件：

- `scripts/lilian/lilian_state.gd`
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
- `data/gushi/prologue_tutorial.yaml`

## 当前冲刺：P2 数值与内容校准

目标：练气到筑基前的成长、资源、战斗难度可测；先把现有内容调稳，不扩高阶境界。

P2 通过标准：

- `tests/run_balance_v1_tests.gd`、`tests/run_config_validation_tests.gd`、`tests/run_lilian_tests.gd` 通过。
- 30-60 分钟手动游玩能看到修炼、历练、炼丹、突破预览四条短期目标。
- 同境界普通战斗不秒杀、不拖沓；精英战有失败风险但不是纯看运气。
- 筑基前资源不会必然卡死，也不会无限膨胀。

### [x] PM-201：平衡基准复核

描述：把当前 `jingjie_balance.yaml` 的练气初期、练气成型、筑基初期基准和自动测试结果对齐，先确认目标线，不急着调内容。

验收：

- `run_balance_v1_tests.gd` 输出记录到任务备注或数值文档。
- 普通敌胜率、普通战时长、精英胜率、跨境界压制都在 acceptance 范围内。
- 如需调参，只改 `data/jingjie_balance.yaml` 或直接相关配置，不做新平衡系统。

涉及文件：

- `data/jingjie_balance.yaml`
- `tests/run_balance_v1_tests.gd`
- `docs/realm-balance-zhuji.md`

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

- `data/guaiwu.yaml`
- `data/didian.yaml`
- `data/lilian_events.yaml`
- `tests/run_lilian_tests.gd`

任务备注：

- 2026-06-24：青岚山脉、野狼谷、黑水沼泽均接入普通 / 精英 / Boss 遭遇；Boss 事件改为高难度检查点。`run_config_validation_tests.gd` 与 `run_lilian_tests.gd` 通过。

### [x] PM-203：筑基前资源循环校准

描述：检查修炼、历练奖励、炼丹消耗、丹药产出、突破准备之间的资源节奏。

验收：

- 历练能稳定产出基础炼丹材料。
- 炼丹不会因材料过少变成摆设，也不会无限放大收益。
- 修炼丹药能明显加速，但会保留灵力驳杂或机会成本。
- 破境准备需要多次活动积累，而不是一次历练直接完成。

涉及文件：

- `data/item.yaml`
- `data/liandan.yaml`
- `data/lilian_rules.yaml`
- `data/tupo_rules.yaml`
- `scripts/sim/liandan_service.gd`
- `scripts/sim/tupo_service.gd`

任务备注：

- 2026-06-24：聚气丹方难度从 45 调整为 38；新手稳火炼制成功率约 0.53，妖丹仍限制批量放大。新增资源闭环回归：历练材料可炼聚气丹，丹药修炼显著加速并产生灵力驳杂，筑基预览仍需要多次活动积累。`run_simulation_tests.gd` 与 `run_config_validation_tests.gd` 通过。

### [x] PM-204：功法 / 技能首版池收敛

描述：只保留练气到筑基前真正会用到的功法、技能、知识效果，补齐缺口，暂不扩高阶流派。

验收：

- 新手默认技能组能应对普通历练。
- 至少有 2 种可理解的战斗倾向：稳健 / 输出。
- 技能知识成长能在 UI 和战斗结果中被感知。
- 同层技能强度差异控制在 `jingjie_balance.yaml` budgets 附近。

涉及文件：

- `data/jineng.yaml`
- `data/xiulian_methods.yaml`
- `data/zhishi_effects.yaml`
- `data/dao_tree.yaml`
- `tests/run_dao_knowledge_tests.gd`

任务备注：

- 2026-06-24：新手默认技能组保持御气弹 / 流风步 / 破空剑气，补齐输出与防御标签；破空剑气基准伤害从 55 收敛到 54，使练气同阶伤害贴近 `jingjie_balance.yaml` 预算。新增练气知识效果与 PM-204 回归，知识成长会影响运行时技能数值和派生属性。`validate-abilities.mjs`、`validate-xiulian-methods.mjs`、`run_dao_knowledge_tests.gd`、`run_config_validation_tests.gd`、`run_zhandou_domain_tests.gd`、`run_simulation_tests.gd`、`run_balance_v1_tests.gd` 通过。

### [x] PM-205：突破前目标可读性

描述：让玩家在筑基前知道自己差什么，不做复杂新面板，只补现有突破 / 角色 / 活动反馈。

验收：

- 突破面板能看懂当前分项、总分、品质档、主要缺口。
- 炼丹、修炼、历练至少各有一条能帮助突破的明确反馈。
- 失败 / 未满足条件提示不只说“不能突破”。

涉及文件：

- `scenes/sim/breakthrough_summary.tscn`
- `scripts/sim/breakthrough_summary.gd`
- `data/tupo_rules.yaml`
- `docs/breakthrough-system.md`

任务备注：

- 2026-06-24：突破页增加主要缺口提示，区分总分不足、下一品质差距与知识点门槛；修炼、炼丹、历练结果各补一条突破准备反馈。新增 `run_pm205_breakthrough_feedback_tests.gd` 覆盖缺口文案。

### [x] PM-206：战斗特效体验版

描述：在战斗节奏和数值稳定后，按技能类型补清晰特效。

验收：

- 普攻、弹道、护盾、治疗、持续伤害有不同反馈。
- 特效不遮挡血条、行动条、战斗日志。
- 低配表现可关闭或降级。

涉及文件：

- `scripts/fight/vfx`
- `scripts/fight/fight_vfx_manager.gd`
- `data/zhandou/presets`

### [x] PM-207：P2 手动游玩验收

描述：做一次 30-60 分钟筑基前游玩记录，验证目标、资源和战斗手感。

验收：

- 记录从新局到第一次突破预览的关键节点。
- 记录普通战、精英战、炼丹、修炼丹药使用后的体感问题。
- 只列 P2 必修问题；纯内容扩展放 P3。

产物：

- `docs/project-management/p2-playtest-notes.md`

## 已完成：P3 内容扩展

启动条件：

- PM-207 完成。
- P2 手动验收没有阻塞级数值、资源、战斗问题。
- `run_config_validation_tests.gd`、`run_lilian_tests.gd`、`run_balance_v1_tests.gd` 通过。

P3 通过标准：

- 新增内容仍走现有地图、历练、战斗、炼丹、知识树系统。
- 每批内容都有配置校验或现有测试覆盖。
- 玩家完成筑基前目标后，有 1 条新的短期目标和 1 条中期目标。
- 只扩到筑基初期可继续玩，不做金丹完整版本。

验收记录：

- 2026-06-25：P3 最小内容包「雾隐溪谷」已落地；自动回归通过，配置路径与可复测路线记录见 `docs/project-management/p3-playtest-notes.md`。

### [x] PM-301：新区域最小内容包

描述：新增 1 个筑基初期可去的区域，包含城市 / 野外入口、基础地点、普通 / 精英 / Boss 遭遇。

验收：

- 世界地图可发现并进入新区域。
- 新区域至少有 1 个资源地点和 1 个危险地点。
- 怪物、掉落、推荐境界、旅行入口通过配置校验。
- 不新增地图系统，只补配置和必要 UI 文案。

涉及文件：

- `data/shijie_map.yaml`
- `data/didian.yaml`
- `data/guaiwu.yaml`
- `scenes/map`
- `tests/run_world_map_tests.gd`
- `tests/run_config_validation_tests.gd`

任务备注：

- 2026-06-25：新增雾隐溪谷、雾溪药圃、封溪残阵和三类筑基初期敌人；`run_config_validation_tests.gd`、`run_world_map_tests.gd`、`run_lilian_tests.gd` 通过。

### [x] PM-302：区域事件链

描述：给新区域做一条 5-7 步事件链，提供探索目标和阶段奖励。

验收：

- 事件链有起点、选择、普通战、精英战、结尾事件。
- 至少 1 个选择影响奖励或风险。
- 事件链能被手动复测，不依赖纯随机撞运气。
- 完成后给出明确下一目标提示。

涉及文件：

- `data/lilian_events.yaml`
- `data/lilian_common_events.yaml`
- `scripts/expedition`
- `tests/run_lilian_tests.gd`

任务备注：

- 2026-06-25：新增「雾溪封阵」6 步链路，覆盖起点选择、法力消耗、普通战、分支奖励、精英战和 Boss 奖励；`run_lilian_tests.gd` 已覆盖关键节点和下一目标。

### [x] PM-303：筑基初期技能 / 功法扩展

描述：补一小组筑基初期技能、功法和知识节点，延续 P2 的稳健 / 输出两种倾向。

验收：

- 至少新增 2 个技能、2 个功法、3 个知识节点。
- 新内容有学习条件和展示文案。
- 技能强度贴近 `jingjie_balance.yaml` 预算，不压过全部旧技能。
- 默认练气技能仍可用，但筑基内容有升级价值。

涉及文件：

- `data/jineng.yaml`
- `data/xiulian_methods.yaml`
- `data/dao_tree.yaml`
- `data/zhishi_effects.yaml`
- `tests/run_dao_knowledge_tests.gd`
- `tests/run_balance_v1_tests.gd`

任务备注：

- 2026-06-25：复用现有筑基技能 / 功法作为雾隐溪谷奖励投放，并补齐 `zhuji.dao_base`、`cultivation.great_cycle`、`body.jade` 三个知识效果；`run_dao_knowledge_tests.gd` 与 `run_balance_v1_tests.gd` 通过。

### [x] PM-304：炼丹与突破辅助扩展

描述：新增 2-3 个围绕筑基初期的丹方和突破辅助道具，服务资源消耗和中期目标。

验收：

- 至少 1 个恢复 / 战斗准备丹方。
- 至少 1 个突破准备相关丹方或道具。
- 材料来源来自 P3 新区域或既有高难历练。
- 不加入火候小游戏或复杂生产线。

涉及文件：

- `data/liandan.yaml`
- `data/item.yaml`
- `data/didian.yaml`
- `scripts/sim/liandan_service.gd`
- `tests/run_simulation_tests.gd`

任务备注：

- 2026-06-25：新增雾隐草、优品雾隐草、阵核碎片、清脉丹、固本道基丹和对应丹方；旧存档炼丹状态会合并默认已知丹方；`run_simulation_tests.gd` 通过。

### [x] PM-305：人物与敌人资产扩展

描述：补 P3 内容需要的最低人物表现，不做全量美术库。

验收：

- 新区域关键 NPC 有头像或立绘。
- 新区域普通敌 / 精英 / Boss 有可识别战斗图。
- 资产命名和路径可被现有角色 / 战斗 UI 直接引用。
- 缺正式图时允许占位，但占位必须风格一致。

涉及文件：

- `assets/art/characters`
- `assets/art`
- `data/guaiwu.yaml`
- `data/gushi`
- `scenes/fightScene.tscn`

任务备注：

- 2026-06-25：采药人 NPC 与雾溪灵鼬、藤甲守卫、封溪阵灵均接入现有风格占位立绘；`run_story_tests.gd` 覆盖映射和资源可加载性。

### [x] PM-306：P3 回归与手动验收

描述：把 P3 新增内容跑一轮自动回归和手动路线，确认没有破坏 P0-P2。

验收：

- `run_config_validation_tests.gd`、`run_world_map_tests.gd`、`run_lilian_tests.gd`、`run_simulation_tests.gd` 通过。
- 手动路线：筑基前目标完成 -> 发现新区域 -> 完成事件链关键节点 -> 获得新功法 / 丹方目标。
- 输出 P3 验收记录。

产物：

- `docs/project-management/p3-playtest-notes.md`

任务备注：

- 2026-06-25：P3 自动回归已完成；手动路线以配置路径核对和可复测清单记录，图形化长时点击游玩留到下一轮 polish。

## 当前冲刺：P4 体验修正与打磨

目标：优先解决真实游玩反馈中的打不过、节奏差、提示不清和小操作别扭；先修现有体验，不扩新内容。

执行顺序：

1. 先做 PM-401A 到 PM-401D，解决打不过后的恢复路径。
2. 再做 PM-402，只收小修，不开新功能。
3. 最后 PM-405 回归，达标后进入 P5 配置扩容。

### [ ] PM-401A：战败成本调参

描述：按 `pm-401-recovery-failure-cost-design.md` 调整战败掉落、伤势和气血下限，让失败有成本但不重开。

验收：

- 战败只扣本次历练战利品，不扣旧背包。
- 战败后一次休息能清掉建议伤势值。
- 失败后玩家保留大部分本次收获，仍能继续推进。
- `run_lilian_tests.gd` 通过。

涉及文件：

- `data/lilian_rules.yaml`
- `scripts/lilian/lilian_reward_service.gd`
- `tests/run_lilian_tests.gd`

### [ ] PM-401B：恢复路径提示

描述：结算页和洞府消息按战败 / 主动返程 / 撤退给出下一步提示，指向休息、炼丹、研读和技能配置。

验收：

- 战败结算能看见保留收获、掉落损失和恢复建议。
- 回洞府后第一眼能看到休息 / 炼丹 / 研读 / 技能配置建议。
- 不新增按钮、不新增弹窗、不重做界面。

涉及文件：

- `scenes/lilian/lilian_jiesuan.tscn`
- `scripts/lilian/lilian_jiesuan.gd`
- `scenes/sim/dongfu.tscn`
- `scripts/sim/dongfu.gd`

### [ ] PM-401C：早期基础材料产出校准

描述：提高早期采集和短历练的基础材料稳定性，避免连一炉基础丹药都开不了。

验收：

- 新局早期完成一次短历练，能凑齐至少一炉回气丹材料。
- 战败后仍能带回一部分基础材料，不出现连续归零体感。
- 不新增保底代码，优先只改地点、事件、奖励预算配置。
- `run_config_validation_tests.gd` 与 `run_lilian_tests.gd` 通过。

涉及文件：

- `data/didian.yaml`
- `data/lilian_common_events.yaml`
- `data/lilian_rules.yaml`

### [ ] PM-401D：功法与技能学习路径提示

描述：不新增功法和技能，先让玩家知道典籍从哪里来、回洞府去哪里研读、学会后去哪里配置。

验收：

- 典籍物品提示明确“在洞府底部研读使用”。
- 结算或洞府消息能在合适时机提示研读和技能配置。
- 技能配置入口无需新增系统，只复用现有入口。

涉及文件：

- `data/item.yaml`
- `scripts/ui/item_info_payload_builder.gd`
- `scripts/sim/dongfu.gd`

任务备注：

- 2026-06-25：完成恢复与失败成本详细设计；结算页底部已增加战败后恢复路径提示，代码与配置调参见 PM-401A 到 PM-401D。

### [ ] PM-402：关键小优化清单

描述：收集并处理只影响当前体验的小优化，超过 30-60 分钟的改动移出 P4。

验收：

- 每项小优化有明确位置和现象。
- 优先处理按钮反馈、文案不清、结算看不懂、入口难找。
- 不做新功能、不重做界面。

产物：

- `docs/project-management/p4-small-fixes.md`

### [ ] PM-405：P4 回归

描述：完成体验修正后跑自动回归，并做一轮短手动路线。

验收：

- `run_config_validation_tests.gd` 通过。
- `run_lilian_tests.gd` 通过。
- `run_balance_v1_tests.gd` 通过。
- 手动路线确认普通战不卡死，精英 / Boss 压力合理。
- 战败后能通过休息、炼丹、研读或调整技能找到下一步。

## 后续阶段：P5 配置扩容

进入条件：

- P4 打不过问题已定位并修正。
- 新局到筑基前目标路线体验稳定。
- 不再需要靠大幅削弱怪物来保证通关。

### [ ] PM-501：药材与材料池扩容

描述：新增一批药材和材料品质，先服务已有炼丹、突破和区域掉落。

验收：

- 每个新药材都有来源地点和用途。
- 每个材料品质有清晰掉落难度。
- 不新增只有名字、没有用途的材料。

涉及文件：

- `data/item.yaml`
- `data/didian.yaml`
- `data/lilian_events.yaml`

### [ ] PM-502：丹药与丹方扩容

描述：新增恢复、修炼、战斗准备、突破准备几类丹药，不做火候小游戏。

验收：

- 每个新丹方有材料来源、产物用途、成功率区间。
- 低阶丹药仍有价值，高阶丹药不是纯数值覆盖。
- 丹药不会绕过 P4 调好的战斗压力。

涉及文件：

- `data/liandan.yaml`
- `data/item.yaml`
- `tests/run_simulation_tests.gd`

### [ ] PM-503：怪物族群扩容

描述：补普通怪、精英、Boss 族群，用于新区域和中期历练。

验收：

- 每组怪物有普通 / 精英 / Boss 梯度。
- 技能槽、属性、掉落池完整。
- 怪物强度贴近当前境界预算。

涉及文件：

- `data/guaiwu.yaml`
- `data/didian.yaml`
- `tests/run_config_validation_tests.gd`

### [ ] PM-504：配置回归

描述：新增配置后做最小回归，防止坏引用和奖励膨胀。

验收：

- `run_config_validation_tests.gd` 通过。
- `run_lilian_tests.gd` 通过。
- `run_simulation_tests.gd` 通过。

## 暂缓任务

- 金丹及以后完整投放：P3 不做。
- 多区域批量内容：先做 1 个新区域验证。
- 新 UI 框架或管理插件：现有 Godot 场景和 Markdown 文档够用。
