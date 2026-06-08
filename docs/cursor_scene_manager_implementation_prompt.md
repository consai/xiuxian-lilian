# Cursor 实施提示词：SceneManager 场景管理

请在当前 Godot 4.6 项目中实现全局 `SceneManager` Autoload，并改造主流程场景跳转。

开始前必须完整阅读：

- `docs/scene_manager_design.md`
- `scripts/core/data_store.gd`
- `scripts/core/scene_manager.gd`（若已存在则对照设计补齐）
- `scripts/expedition/expedition_state.gd`
- `scripts/fight/battle_init_data.gd`
- `scripts/sim/cave_hub.gd`
- `scripts/expedition/location_select.gd`
- `scripts/expedition/expedition_loop.gd`
- `scripts/expedition/expedition_result.gd`
- `scripts/fight/fight_scene.gd`

## 实施顺序

### 阶段 1：SceneManager 与 DataStore.scene

1. 新增 `scripts/core/scene_manager.gd`，实现场景表、payload、`go_to()`、切换锁与守卫。
2. 在 `project.godot` 注册 Autoload：`SceneManager="*res://scripts/core/scene_manager.gd"`
3. 在 `DataStore` 增加 `scene` runtime 与 `set/take/peek/clear_scene_payload`。
4. 将 `set_ui_*` / `take_ui_*` 转发到 scene payload，保持兼容。

完成后运行：`tests/run_scene_manager_tests.gd`（能跑的部分）。

### 阶段 2：普通页面跳转

改造以下脚本，移除直接 `change_scene_to_file()`：

- `scripts/sim/cave_hub.gd`
- `scripts/sim/breakthrough_summary.gd`
- `scripts/expedition/location_select.gd`
- `scripts/expedition/expedition_loop.gd`（非战斗部分）
- `scripts/expedition/expedition_result.gd`

保持 UI 文案与场景结构不变。历练进行中尝试回洞府或进地点选择时，应显示阻塞提示，不静默清除 `ExpeditionState`。

### 阶段 3：战斗往返

1. 实现 `SceneManager.go_fight()`。
2. 改造 `expedition_loop.gd` 战斗入口与 `fight_scene.gd` 战斗结束返回。
3. 保持 `BattleInitData` 为唯一进战数据入口；`goto_fight_scene()` 仅作兼容。

### 阶段 4：清理与验证

1. `rg "change_scene_to_file"` 确认除 `SceneManager`、`BattleInitData.goto_fight_scene`、测试脚本外无业务直接切场景。
2. 补齐 `tests/run_scene_manager_tests.gd` 全部用例。
3. 运行完整回归（见下）。

## 架构约束

- `SceneManager` 不拥有游戏规则；历练规则仍在 `ExpeditionState` 与服务层。
- `GameState.settle_expedition()` 仍是历练写回长期状态的唯一入口。
- `ExpeditionState.start()` / `finish()` 不由 `SceneManager` 替代，仅由 `start_expedition()` 等便捷方法编排调用。
- v1 不做加载屏、异步预载、场景栈回退。
- 不进行与本需求无关的重构。

## 必须通过的测试

```powershell
$env:APPDATA="$PWD\.godot_test_appdata"
$env:LOCALAPPDATA="$PWD\.godot_test_local"

C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_battle_domain_tests.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_simulation_tests.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_expedition_tests.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_expedition_smoke.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --script res://tests/run_scene_manager_tests.gd
C:\Godot_v4.6.2-stable_win64_console.exe --headless --path C:\godot\xiuxian --quit-after 5
git diff --check
```

每完成一个阶段：总结改动文件、运行相关测试、修复报错后再进入下一阶段。

## 验收标准

- 洞府 → 地点选择 → 历练 → 战斗 → 历练/结算 → 洞府 闭环可走通。
- 历练进行中无法静默回洞府或重新进地点选择。
- 突破摘要、历练结算 reason 经 `SceneManager` payload 传递且可被正确消费。
- `import_savedata()` 后 scene runtime 被重置。
- 业务脚本不再散落 `change_scene_to_file()`。
