---
description: UI 场景布局与可复用场景规范
globs: "**/*.{tscn,gd}"
alwaysApply: true
---

# UI 场景布局与复用规范

生成或修改 `.tscn` 时，优先使用场景组合完成布局，不在代码中动态创建固定 UI 节点。

若 目前没有，但功能点可被多个界面复用，应创建新的独立 `.tscn` 场景，再由主场景实例化。
主场景只负责组合与定位，避免重复定义相同功能节点。

## 脚本边界

- 固定 UI 布局写在 `.tscn` 中。
- 脚本只负责数据绑定、状态切换和信号处理。
- 原型阶段要求 TODO 管理代码时，函数只保留接口、信号和 TODO 注释，不实现完整业务逻辑。

## 场景与脚本

### 节点绑定

- 在 `.tscn` 中为需脚本访问的节点设置 `unique_name_in_owner = true`。
- 在 `.gd` 中用 `%NodeName` 获取节点（如 `@onready var _btn: Button = %CloseButton`），避免硬编码 `$"Path/To/Node"`。

### 场景路径与 preload

- **可导航的全屏/面板场景**（经 `change_scene` 切换的）统一登记在 `SceneManager.SCENE_PATHS`，通过 `SceneManager.go_to()` 或对应 helper 进入；不要在各业务脚本中重复 `preload` 全场景或直接 `change_scene_to_file`。
- **子场景、列表项模板、全局浮层 Host**（如 `item.tscn`、行组件、`item_info_popup_host`）仍可在所属脚本中 `preload` 后 `instantiate`。


# 游戏数据存取规范

所有**运行时状态**与**存档数据**必须通过 Autoload 单例 `DataStore`（`res://scripts/core/data_store.gd`）读写，禁止在其他脚本中维护平行的全局字典、静态变量或临时单例来保存游戏进度。

## 数据分区

| 分区 | 用途 | 访问方式 |
|------|------|----------|
| `savedata` | 持久化存档（角色、背包、统计等） | `DataStore.savedata` 或 `GameState` 属性代理 |
| `rundata` | 当前局内临时状态（探险、战斗、场景传参等） | `DataStore.*_runtime()` 访问器 |

优先使用 `DataStore` 提供的访问器，而非直接深钻 `rundata` 嵌套键：

- `game_runtime()` — 最近奖励、探险结算摘要等
- `expedition_runtime()` — 探险进行中状态
- `battle_runtime()` / `set_battle_pending_init()` / `take_battle_pending_init()` — 战斗初始化信封
- `ui_runtime()` 及 `set_ui_*` / `take_ui_*` — UI 跨场景摘要
- `scene_runtime()` / `set_scene_payload()` / `take_scene_payload()` — 场景切换传参

## 推荐写法

```gdscript
# ✅ 存档字段：经 GameState 属性（底层仍写 DataStore.savedata）
GameState.day += 1
GameState.inventory["herb"] = 3

# ✅ 或直接读写 DataStore.savedata
DataStore.savedata["ling_stones"] += 10

# ✅ 局内状态：经 runtime 访问器
DataStore.expedition_runtime()["depth"] = 2
DataStore.set_scene_payload("battle_result", {"won": true})

# ✅ 存档导入导出
var snap := DataStore.export_savedata()
DataStore.import_savedata(snap)
```

## 禁止写法

```gdscript
# ❌ 模块级或类静态游戏状态
static var player_hp := 100
var _cached_inventory := {}

# ❌ 新建平行数据单例
# MyGameData.player = ...

# ❌ 场景间用成员变量长期携带应持久化的进度（应写入 DataStore）
```

## 例外

- `res://data/*.json` 等**静态配置表**由 `JsonLoader` 等工具读取，不属于运行时存档。
- 纯局部、帧内临时变量（如 UI 动画中间值）可留在节点脚本中，但不得替代 `DataStore` 保存跨场景/跨存档的数据。

新增字段时：在 `DataStore._default_savedata()` 或对应 `_default_*()` 中补充默认值，并通过 `coalesce_savedata()` 等合并逻辑保证读档兼容。
