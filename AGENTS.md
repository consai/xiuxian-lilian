---
description: UI 场景布局与可复用场景规范
globs: "**/*.{tscn,gd}"
alwaysApply: true
---

# UI 场景布局与复用规范

生成或修改 `.tscn` 时，优先使用场景组合完成布局，不在代码中动态创建固定 UI 节点。

若 目前没有，但功能点可被多个界面复用，应创建新的独立 `.tscn` 场景，再由主场景实例化。
主场景只负责组合与定位，避免重复定义相同功能节点。

##  场景布局与复用规范脚本边界

- 固定 UI 布局写在 `.tscn` 中。
- 脚本只负责数据绑定、状态切换和信号处理。
- 原型阶段要求 TODO 管理代码时，函数只保留接口、信号和 TODO 注释，不实现完整业务逻辑。

## 场景与脚本

### 场景与脚本节点绑定

- 在 `.tscn` 中为需脚本访问的节点设置 `unique_name_in_owner = true`。
- 在 `.gd` 中用 `%NodeName` 获取节点（如 `@onready var _btn: Button = %CloseButton`），避免硬编码 `$"Path/To/Node"`。

### 场景与脚本场景路径与 preload

- **可导航的全屏/面板场景**（经 `change_scene` 切换的）统一登记在 `SceneManager.SCENE_PATHS`，通过 `SceneManager.go_to()` 或对应 helper 进入；不要在各业务脚本中重复 `preload` 全场景或直接 `change_scene_to_file`。
- **子场景、列表项模板、全局浮层 Host**（如 `item.tscn`、行组件、`item_info_popup_host`）仍可在所属脚本中 `preload` 后 `instantiate`。


# 游戏数据存取规范

所有**运行时状态**与**存档数据**必须通过 Autoload 单例 `DataStore`（`res://scripts/core/data_store.gd`）读写，禁止在其他脚本中维护平行的全局字典、静态变量或临时单例来保存游戏进度。

## 游戏数据存取数据分区

| 分区 | 用途 | 访问方式 |
|------|------|----------|
| `savedata` | 持久化存档（角色、背包、统计等） | `DataStore.savedata` 或 `GameState` 属性代理 |
| `rundata` | 当前局内临时状态（探险、战斗、场景传参等） | `DataStore.*_runtime()` 访问器 |

优先使用 `DataStore` 提供的访问器，而非直接深钻 `rundata` 嵌套键：

- `game_runtime()` — 最近奖励、探险结算摘要等
- `lilian_runtime()` — 探险进行中状态
- `zhandou_runtime()` / `set_zhandou_pending_init()` / `take_zhandou_pending_init()` — 战斗初始化信封
- `ui_runtime()` 及 `set_ui_*` / `take_ui_*` — UI 跨场景摘要
- `scene_runtime()` / `set_scene_payload()` / `take_scene_payload()` — 场景切换传参

## 游戏数据存取推荐写法

```gdscript
# ✅ 存档字段：经 GameState 属性（底层仍写 DataStore.savedata）
GameState.day += 1
GameState.inventory["herb"] = 3

# ✅ 或直接读写 DataStore.savedata
DataStore.savedata["ling_stones"] += 10

# ✅ 局内状态：经 runtime 访问器
DataStore.lilian_runtime()["depth"] = 2
DataStore.set_scene_payload("battle_result", {"won": true})

# ✅ 存档导入导出
var snap := DataStore.export_savedata()
DataStore.import_savedata(snap)
```

## 游戏数据存取禁止写法

```gdscript
# ❌ 模块级或类静态游戏状态
static var player_hp := 100
var _cached_inventory := {}

# ❌ 新建平行数据单例
# MyGameData.player = ...

# ❌ 场景间用成员变量长期携带应持久化的进度（应写入 DataStore）
```

## 游戏数据存取例外

- `res://data/*.yaml` 等**静态配置表**由 `JsonLoader` 等工具读取，不属于运行时存档。
- 纯局部、帧内临时变量（如 UI 动画中间值）可留在节点脚本中，但不得替代 `DataStore` 保存跨场景/跨存档的数据。

新增字段时：在 `DataStore._default_savedata()` 或对应 `_default_*()` 中补充默认值，并通过 `coalesce_savedata()` 等合并逻辑保证读档兼容。




---
description: 离散类型统一用枚举定义，集中放在 scripts/enum/ 并通过 class_name 访问
globs: "**/*.gd"
alwaysApply: true
---

# 枚举定义规范

凡是可以做成枚举的**离散类型**（状态、分类、品质档位、筛选条件等），一律提取为枚举，统一放在 `res://scripts/enum/` 中，并通过 `class_name` 全局访问。

## 枚举定义文件与命名

| 项 | 约定 | 示例 |
|---|---|---|
| 路径 | `res://scripts/enum/enum_<snake_name>.gd` | `enum_itemtype.gd` |
| `class_name` | `Enum` + PascalCase | `EnumItemType`、`EnumQuality` |
| 基类 | `extends RefCounted` | — |
| 内部 `enum` | 简短名词，如 `Type`、`State` | `EnumItemType.Type` |

## 枚举定义推荐结构

```gdscript
class_name EnumItemType
extends RefCounted

enum Type {
	MATERIAL,
	ORE,
	# ...
}

const LABEL_MATERIAL := "材料"

static func label(type: Type) -> String:
	match type:
		Type.MATERIAL:
			return LABEL_MATERIAL
		_:
			return ""
```

- 与配置表/存档字符串对应的枚举，在同文件内提供 `from_label()` / `label()` 等静态转换。
- 颜色、排序、显示名等派生数据，用 `const` 字典或 `static func` 挂在枚举类上，不散落在业务脚本里。

## 枚举定义访问方式

```gdscript
# ✅ 经 class_name 直接访问（首选）
var color := EnumQuality.get_color(quality)
var order := EnumItemType.sort_order(EnumItemType.Type.PILL)

# ✅ 仅需脚本引用常量时，可 preload 后使用
const EnumItemTypeScript := preload("res://scripts/enum/enum_itemtype.gd")
if item_type == EnumItemTypeScript.LABEL_PILL:
	pass
```

## 枚举定义禁止写法

```gdscript
# ❌ 在业务脚本里内联 enum，本可复用的离散类型
enum ItemCategory { MATERIAL, PILL }

# ❌ 魔法字符串/数字散落各处
if item_type == "丹药":
	pass

# ❌ 为枚举再建平行全局单例或静态字典
static var TYPE_LABELS := { ... }
```

## 枚举定义例外

- **仅单个脚本使用的 UI 局部状态**（如面板当前 Tab、一次性动画阶段）可留在该脚本内部 `enum`，不必强行抽到 `scripts/enum/`。
- 新增枚举时，在 `scripts/enum/` 新建文件并注册 `class_name`；旧代码中的魔法值应逐步迁移，而非与新枚举并存两套约定。



# 历史godot执行时的错误:
Godot 校验刚才是 PowerShell 引号吃掉了 $env:，不是项目错误。我换一种引号跑同一个启动检查。
引号还是被外层剥了，我不套二层 PowerShell 了，直接在当前 shell 里设置环境变量再跑。


# 文件命名规范
##  命名组合方式
文件名由“业务含义 + 类型/用途”组合而成。
使用小写字母，单词之间用下划线 _ 连接。
## 中文业务词使用拼音
功能、业务、模块含义使用拼音。
例如：委托 → weituo，帮助 → bangzhu
## 通用英文词可直接使用英文
游戏术语、编程术语、简单英文单词可直接使用英文。
例如：panel、button、item、yes、no
## 最终命名格式
拼音业务词_英文类型词
例如：委托 + 面板 = weituo_panel
例如：任务 + 按钮 = renwu_button
