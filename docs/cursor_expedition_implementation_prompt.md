# Cursor 实施提示词：历练冒险循环

请在当前 Godot 4.6 项目中实现历练冒险循环。

开始前必须完整阅读：

- `docs/expedition_system_design.md`
- `scripts/sim/game_state.gd`
- `scripts/sim/inventory_service.gd`
- `scripts/sim/reward_service.gd`
- `scripts/fight/fight_scene.gd`
- `scripts/fight/scene/fight_scene_combat_flow.gd`
- `scripts/fight/battle_init_data.gd`
- `tests/run_simulation_tests.gd`
- `tests/run_encounter_smoke.gd`

## 实施要求

严格按 `docs/expedition_system_design.md` 的阶段 A、B、C、D 顺序实施。

每完成一个阶段：

1. 总结该阶段新增和修改的文件。
2. 运行该阶段相关测试。
3. 修复所有报错后再进入下一阶段。

不要一次性完成全部修改后才测试。

## 架构约束

- `GameState` 只管理长期养成状态。
- `ExpeditionState` 只管理一次历练中的运行状态。
- 所有历练奖励退出前只存在 `ExpeditionState.loot`。
- `GameState.settle_expedition()` 是历练结果写回长期状态的唯一入口。
- `BattleInitData` 保持为唯一进战入口。
- 战斗场景只回传战斗 summary，不直接发奖励、推进日期或修改背包。
- 场景脚本只负责显示和转发操作，领域规则放入 state/service。
- 随机接口必须支持固定 seed，以便测试稳定复现。
- 不允许历练中保存、读取或调整整备。
- 不修改战斗暂停、走条、技能、Buff 和表现规则。
- 不进行与本需求无关的重构或美术调整。
- 不回退当前工作区中已有的其他改动。

## 必须完成的玩家闭环

```text
洞府
-> 地点选择
-> 开始历练
-> 三选一事件
-> 非战斗事件直接结算，或进入战斗
-> 战斗胜利返回历练界面
-> 继续深入
-> 玩家主动退出
-> 历练结算
-> 奖励入库并推进日期
-> 返回洞府
```

战败必须：

```text
战斗失败
-> 强制结束历练
-> 按配置损失本次战利品
-> 应用 HP 保底和伤势
-> 进入历练结算
-> 返回洞府，游戏继续
```

## 验证命令

使用项目现有 Godot 控制台路径和隔离的测试用户目录运行测试。至少验证：

```powershell
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_battle_domain_tests.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_simulation_tests.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_expedition_tests.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_expedition_smoke.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --quit-after 5
git diff --check
```

运行 Godot 前，为 `APPDATA` 和 `LOCALAPPDATA` 设置项目内隔离目录，避免测试污染真实存档。

## 最终交付说明

完成后请报告：

- 实际实现的场景流转。
- 新增的数据、状态类和服务。
- 旧单场遭遇流程删除或迁移情况。
- 主动退出与战败结算规则。
- 所有测试命令及结果。
- 尚未实现或与设计文档存在差异的部分。

