# 历练冒险循环详细设计

本文档用于指导 Cursor 将当前“一次历练等于一场战斗”的实现，改造为可持续深入、随时主动退出的历练冒险循环。

## 1. 目标与非目标

### 1.1 玩家流程

```text
洞府
  -> 点击历练
  -> 选择地点
  -> 确认整备并开始历练
  -> 从三张事件卡中选择一张
  -> 解决采集 / 奇遇 / 危险 / 战斗事件
  -> 返回历练主界面
  -> 继续深入，或手动退出历练
  -> 历练结算
  -> 战利品进入长期背包，时间推进
  -> 返回洞府
```

玩家在历练中的核心决策是：

> 当前状态是否足以继续深入，还是应该带着已有战利品返回？

### 1.2 MVP 范围

- 一个可完整游玩的地点：青岚山脉。
- 每轮生成三张事件卡，玩家选择其中一张。
- 支持采集、恢复、危险、普通战、精英战和首领战六类事件。
- 战斗结束后回到历练界面，而不是直接回洞府。
- HP、MP、丹药数量在整次历练内持续保留。
- 本次战利品在退出历练前不进入 `GameState.inventory`。
- 玩家可以随时主动退出；战败会强制退出。
- 历练期间禁止保存、读取和更换整备。

### 1.3 本阶段不做

- 随机地图、节点连线或地图寻路。
- 多角色、队伍系统。
- 历练中的装备替换。
- 临时 Buff 跨战保留。当前战斗系统未提供可靠的 Buff 序列化边界。
- 地点解锁、剧情链、商人和复杂事件分支。
- 离线收益。

## 2. 关键规则

规则必须配置在 `data/expedition_rules.json`，不要散落硬编码在场景脚本中。

### 2.1 时间

- 开始历练不立即推进洞府日期。
- 每解决一个事件记为一个 `step`。
- 每 3 个 `step` 折算为 1 天。
- 无论是否解决事件，退出历练至少消耗 1 天。
- 最终消耗天数为 `max(1, ceil(steps / 3.0))`。
- 日期与伤势只在历练结束结算时统一推进。
- 历练结束时，已有伤势减少 `elapsed_days`；战败新增伤势在减少旧伤后再施加。

### 2.2 状态持续

- 开始历练时，从 `GameState` 复制当前 HP、MP、已装备技能、法宝和丹药。
- 每场战斗结束后，将剩余 HP、MP、丹药数量写回 `ExpeditionState`。
- 战斗 Buff、护盾、技能 CD、行动条在每场战斗开始时重置。
- 历练中的恢复事件只修改 `ExpeditionState`，不会提前修改 `GameState`。
- 主动退出或战败结算后，最终 HP、MP、丹药数量才同步回 `GameState`。

### 2.3 战利品

- 所有历练奖励先进入 `ExpeditionState.loot`。
- 主动退出、击败首领后退出：保留 100% 本次战利品。
- 战败：强制退出，堆叠物品保留 50%，向下取整；本次获得的法宝全部丢失。
- 战败后 HP 保底为最大生命的 25%，并施加 3 天伤势。
- 历练前已有物品与法宝永远不会因战败丢失。
- 重复法宝只在最终入库时转换为灵石，沿用 `RewardService.apply_rewards()` 的行为。

### 2.4 深入与难度

- `depth` 从 1 开始。
- 每解决一个事件后 `depth += 1`。
- 普通事件始终可能出现。
- 精英事件从深度 3 开始可能出现。
- 首领事件从深度 6 开始可能出现，击败后本次历练标记为 `boss_defeated`。
- 首领击败后仍允许继续深入，但 MVP 界面应突出“功成返程”按钮。
- 敌人属性倍率：
  - `hp_max`、当前 `hp`、`atk`、`def` 使用 `1.0 + (depth - 1) * 0.08`。
  - `spd`、`crit`、`crit_damage` 不随深度增长。
- 奖励数量倍率使用 `1.0 + (depth - 1) * 0.05`，最终向下取整且至少为 1。

### 2.5 事件抽取

- 每轮展示三张不同事件卡。
- 已展示但未选择的事件在下一轮丢弃。
- 使用地点配置中的 `weight` 加权抽取。
- 不满足 `min_depth`、`max_depth`、`once_per_expedition` 的事件不能进入候选。
- 三张卡中最多出现一张战斗类事件。
- 若合法事件不足三张，允许重复事件类型，但不能重复同一个事件 ID。
- 使用 `ExpeditionState.seed` 与 `rng_state` 保证测试可复现；MVP 不支持历练中存档。

## 3. 状态归属

### 3.1 `GameState`：长期养成状态

保留现有职责：

- 日期、境界、修为、伤势。
- 长期 HP、MP。
- 背包、法宝收藏、整备槽。
- 累计统计和活动记录。
- 洞府活动与突破。

移除或废弃：

- `pending_encounter_id`
- `pending_battle_summary`
- `start_encounter()`
- `settle_pending_battle()`

新增接口：

```gdscript
func begin_expedition(location_id: String) -> Dictionary
func settle_expedition(result: Dictionary) -> Dictionary
func build_player_battle_snapshot(runtime: Dictionary) -> Dictionary
```

`settle_expedition(result)` 是历练状态写回长期状态的唯一入口。场景脚本不得直接修改 `GameState.inventory`、`GameState.hp`、`GameState.day`。

建议的 `result`：

```gdscript
{
    "exit_reason": "manual", # manual / defeated / boss_complete
    "elapsed_days": 2,
    "hp": 61.0,
    "mp": 24.0,
    "items": [
        {"inventory_id": "items_HuiQiDan", "count": 1},
        {"inventory_id": "items_HuiLingDan", "count": 0}
    ],
    "loot": [
        {"kind": "item", "id": "items_LingCao", "count": 4},
        {"kind": "equip", "id": 5002, "count": 1}
    ],
    "stats": {
        "steps": 5,
        "battles": 2,
        "wins": 2,
        "losses": 0,
        "max_depth": 6,
        "boss_defeated": false
    }
}
```

### 3.2 `ExpeditionState`：单次历练运行状态

新增 autoload：

```ini
ExpeditionState="*res://scripts/expedition/expedition_state.gd"
```

职责：

- 管理当前是否正在历练。
- 保存地点、深度、步数、运行时 HP/MP/丹药。
- 保存当前候选事件与本次战利品。
- 接收战斗 summary 并返回历练流程。
- 生成最终结算结果，但不直接修改长期背包。

推荐字段：

```gdscript
var active := false
var phase := "idle" # idle / choosing / resolving / battle / result
var location_id := ""
var depth := 1
var steps := 0
var seed := 0
var rng_state := 0
var runtime := {
    "hp": 0.0,
    "mp": 0.0,
    "items": []
}
var loot: Array = []
var current_choices: Array = []
var current_event_id := ""
var pending_battle_event_id := ""
var pending_battle_summary: Dictionary = {}
var visited_once_events: Array = []
var stats := {}
var event_log: Array = []
```

推荐公共接口：

```gdscript
func start(location_id: String, game_state: Node, seed_override: int = -1) -> Dictionary
func generate_choices() -> Array
func choose_event(event_id: String) -> Dictionary
func build_battle_init() -> Dictionary
func receive_battle_summary(summary: Dictionary) -> void
func settle_pending_battle() -> Dictionary
func can_exit() -> bool
func finish(exit_reason: String) -> Dictionary
func reset() -> void
```

约束：

- `start()` 只能在 `active == false` 时调用。
- `choose_event()` 只能选择 `current_choices` 中的事件。
- `phase == "battle"` 时不能退出。
- `finish()` 返回最终结果并调用 `reset()`；调用者再将结果交给 `GameState.settle_expedition()`。

### 3.3 服务层

新增：

- `scripts/expedition/location_service.gd`
  - 加载与查询地点。
- `scripts/expedition/expedition_event_service.gd`
  - 按地点、深度、已访问事件和 RNG 生成候选。
  - 解决非战斗事件。
- `scripts/expedition/expedition_reward_service.gd`
  - 根据事件、深度生成本次战利品。
  - 只返回奖励数组，不写长期背包。

保留：

- `InventoryService`
  - 继续负责最终物品增减和战斗丹药数量同步。
- `RewardService`
  - 保留 `apply_rewards()` 作为最终入库逻辑。
  - 可复用 `_merge_rewards()` 的逻辑，但应将其改为公共方法 `merge_rewards()`。

废弃：

- `EncounterService`
  - 地点和事件系统完成后删除。
- `data/encounters.json`
  - 数据迁移完成后删除。

## 4. 数据设计

### 4.1 `data/expedition_rules.json`

```json
{
  "schema_version": 1,
  "steps_per_day": 3,
  "minimum_elapsed_days": 1,
  "defeat_loot_item_keep_ratio": 0.5,
  "defeat_keep_new_equips": false,
  "defeat_injury_days": 3,
  "defeat_hp_floor_ratio": 0.25,
  "enemy_depth_growth": 0.08,
  "reward_depth_growth": 0.05,
  "choice_count": 3,
  "max_battle_choices": 1
}
```

### 4.2 `data/locations.json`

```json
{
  "schema_version": 1,
  "locations": {
    "qinglan_mountain": {
      "name": "青岚山脉",
      "subtitle": "林深雾重，灵草与妖兽并存",
      "desc": "适合炼气期修士历练的山脉。",
      "danger": 1,
      "recommended_realm": "炼气一层",
      "event_pool": [
        "qinglan_herbs",
        "qinglan_spring",
        "qinglan_fog",
        "qinglan_wolf",
        "qinglan_serpent",
        "qinglan_boss"
      ],
      "preview_rewards": [
        "items_LingCao",
        "items_YaoDan",
        5002
      ]
    }
  }
}
```

### 4.3 `data/expedition_events.json`

事件通用字段：

```json
{
  "id": "qinglan_herbs",
  "location_id": "qinglan_mountain",
  "type": "gather",
  "name": "林间灵草",
  "desc": "雾气中露出一片泛着微光的灵草。",
  "risk_text": "安全",
  "weight": 30,
  "min_depth": 1,
  "max_depth": 0,
  "once_per_expedition": false,
  "effects": [],
  "rewards": []
}
```

支持的事件类型与字段：

- `gather`
  - `rewards`：直接加入本次战利品。
- `recover`
  - `effects`：支持 `heal_hp_percent`、`restore_mp_percent`。
- `hazard`
  - `effects`：支持 `damage_hp_percent`、`drain_mp_percent`。
  - 危险不会直接触发战败；HP 最低降至 1。
- `battle`
  - `enemy`：与现有 `encounters.json.enemy` 结构一致。
  - `rewards`、`reward_rolls`。
- `elite`
  - 与 `battle` 相同，但默认更高奖励，`min_depth >= 3`。
- `boss`
  - 与 `battle` 相同，`min_depth >= 6`，`once_per_expedition = true`。

首个地点至少配置：

| ID | 类型 | 最低深度 | 用途 |
|---|---|---:|---|
| `qinglan_herbs` | gather | 1 | 稳定灵草 |
| `qinglan_ore` | gather | 2 | 少量灵石或材料 |
| `qinglan_spring` | recover | 1 | 恢复 MP |
| `qinglan_shelter` | recover | 2 | 恢复 HP |
| `qinglan_fog` | hazard | 1 | 扣除 MP |
| `qinglan_cliff` | hazard | 3 | 扣除 HP |
| `qinglan_wolf` | battle | 1 | 普通战 |
| `qinglan_serpent` | elite | 3 | 精英战 |
| `qinglan_boss` | boss | 6 | 地点首领 |

## 5. 场景与界面

### 5.1 地点选择页

替换当前：

- `scenes/sim/encounter_select.tscn`
- `scripts/sim/encounter_select.gd`

新增：

- `scenes/expedition/location_select.tscn`
- `scripts/expedition/location_select.gd`

页面内容：

- 地点名称、描述、危险度、推荐境界、可能获得。
- 当前 HP、MP、法宝与丹药槽摘要。
- “开始历练”与“返回洞府”按钮。
- MVP 只有一个地点，但结构必须支持多个地点。

点击“开始历练”：

1. 调用 `ExpeditionState.start(location_id, GameState)`。
2. 成功后进入 `res://scenes/expedition/expedition_loop.tscn`。
3. 不推进日期，不修改长期背包。

### 5.2 历练主界面

新增：

- `scenes/expedition/expedition_loop.tscn`
- `scripts/expedition/expedition_loop.gd`

布局要求：

- 顶部：地点、深入层数、预计已消耗天数。
- 左侧：HP、MP、丹药剩余数量、本次统计。
- 中间：三张事件卡。
- 右侧：本次战利品列表与最近事件日志。
- 底部固定按钮：“退出历练”。

事件卡展示：

- 名称、事件类型、风险说明、可能效果。
- 战斗类显示敌人名称与风险。
- 不展示精确随机奖励数量。

交互：

- 点击事件卡后立即锁定其他卡，避免重复点击。
- 非战斗事件在本页结算，展示一条结果反馈，再生成下一轮。
- 战斗事件调用 `BattleInitData.goto_fight_scene()`。
- `phase == "battle"` 或正在播放结果反馈时禁用退出按钮。

### 5.3 战斗返回

修改 `scripts/fight/fight_scene.gd`：

当前行为：

```gdscript
GameState.settle_pending_battle()
get_tree().change_scene_to_file(GameState.HUB_SCENE)
```

目标行为：

```gdscript
if ExpeditionState.active and ExpeditionState.phase == "battle":
    ExpeditionState.settle_pending_battle()
    if ExpeditionState.active:
        get_tree().change_scene_to_file(ExpeditionState.LOOP_SCENE)
    else:
        get_tree().change_scene_to_file(ExpeditionState.RESULT_SCENE)
    return
```

`_on_battle_finished(summary)` 应将 summary 交给 `ExpeditionState.receive_battle_summary(summary)`。

胜利：

- 更新运行时 HP、MP、丹药。
- 将奖励加入本次战利品。
- 增加步数、深度和战斗统计。
- 回历练主界面。

战败：

- 更新运行时 HP、MP、丹药。
- 标记强制撤退。
- 不发当前战斗奖励。
- 直接进入历练结算页。

### 5.4 历练结算页

新增：

- `scenes/expedition/expedition_result.tscn`
- `scripts/expedition/expedition_result.gd`

展示：

- 退出原因：主动返程 / 战败撤退 / 首领告捷。
- 深入层数、历练步数、消耗天数。
- 战斗次数、胜负。
- 最终 HP、MP。
- 获得与损失的战利品。
- 战败后的伤势提示。

进入结算页前：

1. `ExpeditionState.finish(reason)` 生成最终结果。
2. `GameState.settle_expedition(result)` 将状态写回长期状态。
3. 将用于展示的结算摘要保存在 scene tree meta 或单独的只读 `last_expedition_result`。

点击“返回洞府”后进入 `GameState.HUB_SCENE`。

### 5.5 洞府入口

修改 `scripts/sim/cave_hub.gd`：

- “外出历练”进入 `location_select.tscn`。
- 历练返回后展示最近一次历练摘要。
- 洞府保存、读取逻辑保持不变。
- 若因调试或异常回到洞府且 `ExpeditionState.active == true`，应先阻止洞府操作并提示状态异常，不要静默覆盖历练状态。

## 6. 战斗边界

`BattleInitData` 保持为进战唯一入口，不让战斗场景知道地点、深度、奖励或长期背包。

进战数据由 `ExpeditionState.build_battle_init()` 组装：

1. 调用 `GameState.build_player_battle_snapshot(ExpeditionState.runtime)`。
2. 从当前事件复制敌人配置。
3. 应用深度敌人倍率。
4. 设置战斗时间、自动战斗配置等。

战斗回传 summary 继续只包含：

```gdscript
{
    "outcome": "win",
    "player_runtime": {
        "hp": 61.0,
        "mp": 24.0,
        "items": []
    }
}
```

禁止把以下状态带出单场战斗：

- Buff / DoT。
- 护盾。
- 技能与法宝 CD。
- 行动条进度。
- 战斗经过时间。

## 7. 存档策略

- 洞府仍是唯一允许保存与读取的场景。
- `GameState.to_dict()` 不包含 `ExpeditionState`。
- 读取存档时必须调用 `ExpeditionState.reset()`，防止内存中残留一次历练。
- 不需要提升当前 `SaveService.SCHEMA_VERSION`，因为长期存档结构只新增可选统计字段。
- 如果从长期存档中删除旧的 pending 字段，不需要迁移，它们当前未被序列化。

## 8. 统计与日志

扩展 `GameState.totals`：

```gdscript
{
    "expeditions": 0,
    "expedition_steps": 0,
    "max_depth": 0,
    "bosses_defeated": 0,
    "battles": 0,
    "wins": 0,
    "losses": 0,
    "items_gained": 0
}
```

一次历练只在最终结算时向 `activity_log` 写一条记录，例如：

```text
第 8 日：青岚山脉历练，深入 6 层，胜 2 场，带回灵草 x4、妖丹 x1
```

不要为每个历练事件写入长期 `activity_log`；详细过程只存在 `ExpeditionState.event_log`，并在结算后丢弃。

## 9. 实施顺序

Cursor 应按以下顺序实施，并在每个阶段运行现有测试与新增测试。

### 阶段 A：建立领域层，不改界面

1. 新增三个历练数据文件。
2. 新增 `LocationService`、`ExpeditionEventService`、`ExpeditionRewardService`。
3. 新增 `ExpeditionState`，注册 autoload。
4. 在 `GameState` 中新增 `build_player_battle_snapshot()` 与 `settle_expedition()`。
5. 为领域层编写无场景测试。

完成标准：

- 固定 seed 可稳定生成三张合法事件卡。
- 非战斗事件可修改运行时状态、战利品、深度与步数。
- 主动退出与战败能生成正确结算结果。

### 阶段 B：接入战斗往返

1. 改造战斗返回逻辑，使其优先返回历练流程。
2. 让 `ExpeditionState` 创建战斗数据并接收 summary。
3. 改写端到端烟雾测试。

完成标准：

- 从历练触发战斗。
- 胜利后回历练主界面。
- HP、MP、丹药剩余数量在下一场战斗中保持。
- 战败后进入历练结算页。

### 阶段 C：完成场景闭环

1. 新增地点选择页。
2. 新增历练主界面。
3. 新增历练结算页。
4. 修改洞府入口与返回提示。
5. 删除旧遭遇选择页与旧 `EncounterService`。

完成标准：

- 玩家可从洞府开始历练，连续解决多个事件，手动退出并回到洞府。
- 本次战利品只在最终结算后进入背包。

### 阶段 D：清理与数据校验

1. 删除 `GameState` 中旧的单场遭遇 pending 流程。
2. 删除 `data/encounters.json`。
3. 新增启动时数据校验：
   - 地点引用的事件存在。
   - 战斗事件敌人配置可通过 `BattleInitData.collect_errors()`。
   - 奖励引用的物品与法宝存在。
4. 更新测试文档。

## 10. 测试计划

新增 `tests/run_expedition_tests.gd`：

1. `start creates isolated runtime`
   - 开始历练复制 GameState HP/MP/丹药。
   - 修改运行时不会提前修改 GameState。
2. `choices obey depth and battle cap`
   - 每轮三张不同卡。
   - 最多一张战斗卡。
   - 深度不足不会出现精英和首领。
3. `non battle events advance expedition`
   - 采集、恢复、危险正确结算。
   - 步数与深度各增加 1。
4. `manual exit keeps all loot`
   - 主动退出后全部战利品进入长期背包。
5. `defeat exit applies loss and injury`
   - 堆叠物品保留 50%。
   - 新法宝丢失。
   - HP 保底与伤势正确。
6. `elapsed days use step ceiling`
   - 0、1、3 步消耗 1 天，4、6 步消耗 2 天。
7. `battle win returns to expedition`
   - 胜利 summary 更新运行时并添加奖励，不推进 GameState 日期。
8. `battle loss forces expedition result`
   - 战败后不能继续生成事件卡。
9. `boss requires depth and marks completion`
   - 深度不足不出现首领，击败后标记完成。
10. `game settlement occurs once`
   - 重复提交同一个结果不会重复发奖或推进日期。

改写 `tests/run_encounter_smoke.gd` 为 `tests/run_expedition_smoke.gd`：

```text
新游戏
-> 开始青岚山脉历练
-> 强制选择普通战事件
-> 自动战斗胜利
-> 返回历练界面
-> 主动退出
-> 进入历练结算
-> 返回洞府
```

必须保留并继续通过：

- `tests/run_battle_domain_tests.gd`
- 与洞府活动、背包、存档相关的 `tests/run_simulation_tests.gd`

## 11. 验收标准

- 点击洞府“外出历练”后先选择地点，不会直接开战。
- 开始历练后可连续解决至少 10 个事件。
- 每轮玩家都能在三张事件卡之间做选择。
- 每次解决事件后，玩家可以继续深入或主动退出。
- 战斗胜利后返回历练界面，不返回洞府、不推进洞府日期、不立即发长期奖励。
- 下一场战斗继承上一场战斗剩余 HP、MP 和丹药数量。
- 主动退出完整保留本次战利品，并按步数推进日期。
- 战败强制退出，正确损失本次战利品、施加伤势，但不会结束游戏。
- 历练期间无法保存、读取或调整整备。
- 洞府原有修炼、休息、突破和三槽存档继续工作。
- 所有领域测试与端到端烟雾测试通过，Godot headless 启动无错误。

## 12. Cursor 执行约束

- 先阅读本文档和现有实现，再开始修改。
- 保持 `BattleInitData` 为唯一进战入口。
- 场景脚本只负责显示与转发操作，不直接实现抽卡、奖励或结算规则。
- 所有随机行为允许传入固定 seed，测试不得依赖真实随机结果。
- 不要在本迭代顺手重做洞府或战斗 UI 美术。
- 不要修改现有战斗暂停 / 走条规则。
- 不要回退与本功能无关的工作区改动。
- 每完成一个实施阶段就运行相关测试，最后运行全部测试和 `git diff --check`。

