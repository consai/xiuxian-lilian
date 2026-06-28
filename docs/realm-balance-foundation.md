# 境界战斗数值配置基础

本文说明当前战斗数值的落地点，方便后续扩展金丹、元婴及更高境界时只改配置、少改代码。

## 配置入口

核心配置位于 `res://data/realm_balance.yaml`。

人物 `Lv1-Lv90` 基础属性成长、大境界质变和怪物换算基准见 `res://docs/player-base-attribute-progression.md`；机器可读配置位于 `player_level_curve` 与 `monster_design_baseline`。

境界突破门槛位于 `res://data/simulation.yaml > realms[*].breakthrough_at`，按公式 `300 * 境界序号^2` 生成。该字段表示累计修为门槛，不是本层增量。

| 区块 | 用途 |
|---|---|
| `rules` | 记录防御、命中、控制和速度的全局常数。当前运行时常数仍在 `ZhandouAttr` / `ZhandouBalance` 中定义，本区块是设计基准与后续迁移入口。 |
| `major_realms` | 大境界顺序、内容系数与普通/精英/Boss 战目标时长。 |
| `player_level_curve` | 人物内容等级、每级根基成长、大境界脉冲和标准面板生成规则。 |
| `monster_design_baseline` | 怪物以标准玩家为母板时的强度换算、模板系数与 Boss 预算约束。 |
| `combat_attribute_formula` | 四维根基推导战斗面板的公式。 |
| `realm_flat_per_layer` | 每提升一个小境界给的固定面板加成。 |
| `standard_players` | 自动化平衡测试使用的标准玩家快照。 |
| `benchmark_enemies` | 自动化平衡测试使用的标杆敌人。 |
| `encounter_bands` | 弱敌、普通、强敌、精英、Boss 的强度预算区间。 |
| `budgets` | 技能、功法和槽位预算护栏。 |
| `acceptance` | 平衡验收指标，例如胜率、战斗时长和资源余量。 |

运行时读取入口是 `RealmBalanceService`：

```gdscript
const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")

var attrs := RealmBalanceServiceScript.build_base_combat_attrs(foundations)
var realm_mods := RealmBalanceServiceScript.realm_flat_modifiers(realm_index)
var enemy := RealmBalanceServiceScript.benchmark_enemy_attrs("qi_normal")
```

`CharacterStats.build_combat_attrs()` 已经接入 `RealmBalanceService`，因此角色面板公式和境界固定加成现在都从配置生成。

## 后续配置一个新境界

1. 在 `data/simulation.yaml` 增加境界层级，用 `major_realm` 指向大境界 ID。
2. 在 `data/realm_balance.yaml > major_realms` 确认这个大境界存在，并配置内容系数与目标战斗时长。
3. 在 `standard_players` 增加该阶段的标准玩家，例如 `core_early`、`core_mature`。
4. 在 `benchmark_enemies` 增加普通、精英、跨境界标杆敌人。
5. 用 `tests/run_balance_v1_tests.gd` 的模式扩展新的胜率与时长验收。

## 当前保持不变的数值

本次只是把硬编码基础抽成配置，不主动改战斗手感。

- 四维 10 的基础面板仍是：气血 100、法力 100、物攻 30、法攻 32、物防 20、法防 24、速度 100。
- 速度现在由身法主导、神识辅助，避免肉身同时支撑气血、物攻、物防和出手频率。
- 每个小境界仍提供：气血 +6、法力 +6、物攻 +1.8、法攻 +1.92、物防 +1.2、法防 +1.44、速度 +3。
- 现有练气/筑基平衡测试仍使用御气弹、练气普通敌、练气精英敌和筑基普通敌作为首版纵切。

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
