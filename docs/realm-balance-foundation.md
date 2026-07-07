# 境界战斗数值配置基础

本文说明当前战斗数值的落地点，方便后续扩展金丹、元婴及更高境界时只改配置、少改代码。

## 配置入口

核心配置位于 `res://data/exportjson/yunxing_params/jingjie_balance*.json`。

人物每级基础四维与基础战斗面板位于 `res://data/exportjson/realms.json`；怪物换算基准位于 `monster_design_baseline`。

境界与突破规则位于 `res://data/exportjson/realms.json` 与 `res://data/exportjson/yunxing_params/tupo_rules*.json`；设计时以导出 JSON 为准。

| 区块 | 用途 |
|---|---|
| `rules` | 记录防御、控制和速度的全局常数。当前运行时常数仍在 `ZhandouAttr` / `ZhandouBalance` 中定义，本区块是设计基准与后续迁移入口。 |
| `major_realms` | 大境界顺序、内容系数与普通/精英/Boss 战目标时长。 |
| `realms.json` | 人物每级基础四维、修为门槛与基础战斗面板。 |
| `monster_design_baseline` | 怪物以标准玩家为母板时的强度换算、模板系数与 Boss 预算约束。 |
| `combat_attribute_formula` | 四维根基推导战斗面板的公式。 |
| `standard_players` | 自动化平衡测试使用的标准玩家快照。 |
| `benchmark_enemies` | 自动化平衡测试使用的标杆敌人。 |
| `encounter_bands` | 弱敌、普通、强敌、精英、Boss 的强度预算区间。 |
| `budgets` | 技能、功法和槽位预算护栏。 |
| `acceptance` | 平衡验收指标，例如胜率、战斗时长和资源余量。 |

运行时读取入口是 `RealmBalanceService`：

```gdscript
const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")

var realm := RealmService.realms()[realm_index]
var attrs := realm.get("combat_attrs", {})
var enemy := RealmBalanceServiceScript.benchmark_enemy_attrs("qi_normal")
```

角色基础面板直接使用当前 `realms.json` 行，功法、装备等修正再在运行时叠加。

## 后续配置一个新境界

1. 在配置表导出 `data/exportjson/realms.json` 对应境界层级，用 `major_realm` 指向大境界 ID。
2. 在 `data/exportjson/yunxing_params/jingjie_balance_major_realms.json` 确认这个大境界存在，并配置内容系数与目标战斗时长。
3. 在 `standard_players` 增加该阶段的标准玩家，例如 `core_early`、`core_mature`。
4. 在 `benchmark_enemies` 增加普通、精英、跨境界标杆敌人。
5. 用 `tests/run_balance_v1_tests.gd` 的模式扩展新的胜率与时长验收。

## 当前基础公式

基础面板由 `realms.json` 每级四维按公式导出，运行时只叠加功法、装备等额外修正。

- 四维 10 的基础面板：气血 180、法力 130、物攻 25、法攻 28、物防 12、法防 19、速度 125。
- 出手速度 = 身法 * 2 + 神识 * 0.5 + 100。
- 控制强度 = 神识 * 1.6 + 灵力 * 0.5；控制抗性 = 肉身 + 神识 * 1.2。

## PM-201 基准复核记录

2026-06-24 运行 `tests/run_balance_v1_tests.gd` 通过，未调参。

| 场景 | 胜率 | 平均时长 | 胜利气血余量 | 验收 |
|---|---:|---:|---:|---|
| 练气初期 vs 普通敌 | 0.800 | 8.72 秒 | 0.260 | 通过 |
| 练气初期 vs 精英敌 | 0.425 | 8.72 秒 | 0.171 | 通过 |
| 练气成型 vs 筑基普通敌 | 0.050 | 5.83 秒 | 0.108 | 通过 |

## 设计原则

- 境界系数用于内容预算，不作为隐藏伤害倍率。
- 面板成长负责“变强”，技能/功法/法宝负责“解题方式”。
- 新境界优先补标准玩家和标杆敌人，再补具体副本怪物。
- 强敌和 Boss 不应只堆面板，纯属性预算最多占 Boss 强度的大约 60%。

## 战斗运行时约定

- 主动技能必须显式配置 `powerScale`，即使是纯控制技也要写 `0`。
- 主动技能成本统一写入 `combat.costs`。当前运行时只有一个战斗资源池，因此 `mana`、`stamina`、`spirit` 都会折算扣除当前法力池，但 UI 会保留原资源标签，后续拆多资源时不用改技能表结构。
- `damage_true` 及法则、虚空、天劫类真伤会保留攻击倍率，但跳过物防/法防减伤。
- `armor_pierce`、`space_pierce`、`law_pierce` 都作用在前一个伤害段上。
- `dash_distance`、`array_duration`、`remote_control_range` 等暂时没有战场实体承载的效果只作为展示/策略信息，不参与即时伤害结算。
