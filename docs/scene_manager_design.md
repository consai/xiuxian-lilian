# SceneManager 场景管理设计

本文档定义全局 `SceneManager` Autoload 的职责、API、守卫规则与数据边界。目标是把主流程场景跳转从各页面脚本收束为可审计、可测试、可扩展的导航层，而不替代 `GameState`、`ExpeditionState` 或 `BattleInitData` 的领域职责。

## 1. 目标与非目标

### 1.1 目标

- 统一管理洞府、地点选择、历练主界面、历练结算、战斗、突破摘要之间的同步场景切换。
- 为跨场景 UI 数据提供一次性或可窥视的 payload 通道。
- 在导航边界执行历练状态守卫，避免错误场景破坏进行中历练。
- 战斗往返仍由 `BattleInitData` 持有进战数据，`SceneManager` 只负责写入 pending 并切换场景。

### 1.2 非目标（v1）

- 复杂加载屏、异步资源预载、转场动画。
- 场景栈回退或多层 modal 导航。
- 拥有游戏规则或长期养成状态。
- 替代 `ExpeditionState.start()` / `finish()` 等领域 API。

## 2. 架构位置

```text
UI 场景脚本
    -> SceneManager（导航 + 守卫 + payload）
        -> DataStore.scene（运行时导航状态）
        -> ExpeditionState / GameState（领域状态，只读守卫）
        -> BattleInitData.set_pending()（进战数据）
        -> SceneTree.change_scene_to_file()（底层切换）
```

`DataStore` 的 `set_ui_*` / `take_ui_*` 方法保留为兼容包装，内部转发到 `scene.payloads`，避免一次性破坏旧测试或调用点。

## 3. 场景 ID 与路径

| 常量 | scene_id | 路径 |
|------|----------|------|
| `HUB` | `hub` | `res://scenes/sim/cave_hub.tscn` |
| `LOCATION_SELECT` | `location_select` | `res://scenes/expedition/location_select.tscn` |
| `EXPEDITION_LOOP` | `expedition_loop` | `res://scenes/expedition/expedition_loop.tscn` |
| `EXPEDITION_RESULT` | `expedition_result` | `res://scenes/expedition/expedition_result.tscn` |
| `FIGHT` | `fight` | `res://scenes/fightScene.tscn` |
| `BREAKTHROUGH_SUMMARY` | `breakthrough_summary` | `res://scenes/sim/breakthrough_summary.tscn` |

Autoload 注册：

```ini
SceneManager="*res://scripts/core/scene_manager.gd"
```

## 4. 核心 API

```gdscript
func go_to(scene_id: String, payload: Dictionary = {}, options: Dictionary = {}) -> Dictionary
func go_hub(payload: Dictionary = {}) -> Dictionary
func go_location_select() -> Dictionary
func start_expedition(location_id: String, seed_override: int = -1) -> Dictionary
func go_expedition_loop() -> Dictionary
func go_expedition_result(reason: String = "manual") -> Dictionary
func go_breakthrough_summary(summary: Dictionary) -> Dictionary
func go_fight(battle_data: Dictionary, source: String = "scene_manager") -> Dictionary
func take_payload(scene_id: String) -> Dictionary
func peek_payload(scene_id: String) -> Dictionary
```

所有导航方法返回统一结果字典：

- 成功：`{"ok": true, "scene_id": "...", "path": "res://..."}`
- 失败：`{"ok": false, "error": "..."}`，必要时附带 `"blocked": true`

## 5. 守卫规则

| 目标场景 | 允许条件 | 拒绝时行为 |
|----------|----------|------------|
| `EXPEDITION_LOOP` | `ExpeditionState.active == true` 且未进入结算（`should_go_to_result() == false`） | 返回错误，不切场景 |
| `EXPEDITION_RESULT` | `ExpeditionState.active == true` 或 `last_finish_result` 非空 | 返回错误；结果页 `_ready` 可回退洞府 |
| `LOCATION_SELECT` | `ExpeditionState.active == false` | 返回错误，不破坏历练状态 |
| `FIGHT` | 仅允许 `go_fight()` | 直接 `go_to(FIGHT)` 拒绝 |
| `HUB` | 默认允许；若 `ExpeditionState.active == true` 则拒绝 | 返回 `blocked: true`，不清历练状态 |

`start_expedition()` 先调用 `ExpeditionState.start()`，成功后再 `go_expedition_loop()`。

## 6. Payload 与 DataStore.scene

`DataStore.reset_rundata()` 初始化：

```gdscript
"scene": {
    "current_id": "",
    "previous_id": "",
    "transitioning": false,
    "payloads": {},
    "history": [],
}
```

- `set_scene_payload(scene_id, payload)`：写入目标场景待消费数据。
- `take_scene_payload(scene_id)`：读取并清除（一次性消费）。
- `peek_scene_payload(scene_id)`：只读副本。
- `import_savedata()` 会 `reset_rundata()`，从而重置 scene runtime。

### 6.1 现有 UI payload 映射

| 旧 API | scene_id | payload 形状 |
|--------|----------|--------------|
| `set_ui_breakthrough_summary` | `breakthrough_summary` | 突破结果字典 |
| `set_ui_expedition_exit_reason` | `expedition_result` | `{"reason": "manual"}` 等 |
| `peek_ui_expedition_exit_reason` | `expedition_result` | 读取 `reason` |
| `take_ui_breakthrough_summary` | `breakthrough_summary` | 同 `take_payload` |

## 7. 切换锁（transition lock）

`go_to()` / `go_fight()` 在发起 `change_scene_to_file` 前将 `scene.transitioning = true`。同帧重复调用返回 `transition_in_progress`。下一帧由 `SceneManager` 释放锁，避免双重切换。

## 8. 战斗往返

1. 历练事件触发战斗：`SceneManager.go_fight(battle_data, "expedition")`
2. `go_fight()` 校验数据 → `BattleInitData.set_pending()` → 切换 `FIGHT`
3. `FightScene` 战斗结束：
   - 需结算：`go_expedition_result(reason)`
   - 继续历练：`go_expedition_loop()`

`BattleInitData.goto_fight_scene()` 保留给测试与编辑器直调，不感知远征/洞府业务流向。

## 9. 业务脚本改造清单

| 脚本 | 改造 |
|------|------|
| `cave_hub.gd` | `go_location_select()` / `go_breakthrough_summary()` |
| `breakthrough_summary.gd` | `take_payload(BREAKTHROUGH_SUMMARY)` / `go_hub()` |
| `location_select.gd` | `start_expedition()` / `go_hub()` |
| `expedition_loop.gd` | `go_fight()` / `go_expedition_result()` / 非 active 时 `go_hub()` |
| `expedition_result.gd` | `peek_payload(EXPEDITION_RESULT)` / `go_hub()` |
| `fight_scene.gd` | `go_expedition_loop()` / `go_expedition_result()` |

业务脚本不得直接调用 `get_tree().change_scene_to_file()`（测试烟雾脚本除外）。

## 10. 测试

`tests/run_scene_manager_tests.gd` 覆盖：

- 洞府切换、地点选择守卫、历练启动、循环/结算 payload、突破摘要一次性消费、战斗 pending、切换锁、`import_savedata` 重置 scene runtime。

回归命令见 `docs/cursor_scene_manager_implementation_prompt.md`。

## 11. 后续扩展（非 v1）

- 异步加载与进度回调。
- 场景栈 `push` / `pop`。
- 统一转场动画钩子。
- 导航事件遥测（`DataEvents`）。
