# 道观委托系统 UI 设计文档

> **关联文档**：玩法规则见 `docs/weituo-system.md`。本文只定义 UI、交互、场景拆分和验收，不重复规则实现。

---

## 1. UI 目标

委托榜是小道观里的轻量事务面板，不做新的全屏玩法。玩家打开后应在 5 秒内看懂三件事：

1. 哪些委托能接。
2. 进行中的委托还差什么。
3. 哪些委托现在可以提交、提交后拿什么奖励。

设计优先级：可读性 > 操作少 > 氛围。v1 不做拖拽、不做分页动画、不做 NPC 对话树。

---

## 2. 场景入口

### 2.1 小道观入口

入口放在小道观主界面的功能按钮区，名称为「委托榜」。

| 状态 | 入口表现 | 说明 |
|------|----------|------|
| 无可提交 | 普通米黄按钮 | 与背包、丹炉同级 |
| 有可提交 | 按钮右上角红点或小印记 | 不显示数字，避免另做计数组件 |
| 有新委托 | 按钮轻微高亮 | 只在刷新后第一次进入前显示 |

接入点：

- 规范目标：`scenes/sim/dongfu.tscn` / `scripts/sim/dongfu.gd`
- 当前项目实际据点场景可按现有命名接：`scenes/sim/dongfu.tscn`

### 2.2 打开方式

- 点击「委托榜」按钮，在当前场景上方打开弹层。
- 不切换全屏场景，不走 `SceneManager.go_to()`。
- 面板关闭后回到小道观，不改变玩家当前状态。

---

## 3. 场景拆分

固定 UI 节点全部写在 `.tscn` 中，脚本只做数据绑定、按钮状态和信号转发。

```text
scenes/ui/weituo_board_panel.tscn
scenes/ui/components/weituo_card.tscn
scenes/ui/components/weituo_requirement_row.tscn

scripts/ui/weituo_board_panel.gd
scripts/ui/components/weituo_card.gd
scripts/ui/components/weituo_requirement_row.gd
```

可复用节点：

- 奖励格优先复用 `scenes/items/item.tscn` 或现有奖励展示逻辑。
- 图标使用现有资源：`btn_close.png`、`btn_lv.png`、`btn_mihuang.png`、`headlabel.png`、`lingshi.png`、`item_cao.png`、`flag.png`、`baoshang.png`。
- 按钮反馈复用 `scripts/ui/press_scale_feedback.gd`。

---

## 4. 主面板布局

参考分辨率：`1280x800`。

面板是居中弹层：

- Dimmer：全屏半透明深棕，`Color(0.12, 0.08, 0.04, 0.42)`。
- 主面板：`1040 x 680`，居中。
- 标题牌：顶部居中，使用 `headlabel.png` 或现有标题 StyleBox。
- 关闭按钮：右上角贴图按钮。

```text
┌──────────────────────────────────────────────────────────────┐
│                         委 托 榜                       X     │
├──────────────┬───────────────────────────────┬───────────────┤
│ 筛选         │ 委托列表                      │ 委托详情      │
│ 全部         │ ┌───────────────────────────┐ │ 标题/发布者   │
│ 可接受       │ │ 委托卡：采药急件          │ │ 描述          │
│ 进行中       │ │ 需求摘要 / 奖励预览       │ │ 需求列表      │
│ 可提交       │ └───────────────────────────┘ │ 奖励列表      │
│ 已完成       │ ┌───────────────────────────┐ │ 操作按钮      │
│              │ │ 委托卡：巡青岚山路        │ │               │
│ 当前 1/3     │ └───────────────────────────┘ │               │
└──────────────┴───────────────────────────────┴───────────────┘
```

尺寸建议：

| 区域 | 位置 | 尺寸 |
|------|------|------|
| `Panel` | 居中 | `1040 x 680` |
| `TitleBack` | 顶部居中 | `360 x 72` |
| `FilterPanel` | 左侧 | `160 x 560` |
| `ListPanel` | 中部 | `520 x 560` |
| `DetailPanel` | 右侧 | `300 x 560` |
| `FooterHint` | 底部 | `960 x 34` |

---

## 5. 节点树

### 5.1 `weituo_board_panel.tscn`

```text
WeituoBoardPanel (Control)
├─ Dimmer (ColorRect)
├─ Panel (Panel)
│  ├─ TitleBack (Panel / TextureRect)
│  │  └─ TitleLabel (Label) unique
│  ├─ CloseButton (TextureButton) unique
│  ├─ HeaderInfo (HBoxContainer)
│  │  ├─ ActiveLimitLabel (Label) unique
│  │  └─ RefreshLabel (Label) unique
│  ├─ Body (HBoxContainer)
│  │  ├─ FilterPanel (PanelContainer)
│  │  │  └─ FilterButtons (VBoxContainer)
│  │  │     ├─ AllFilterButton (Button) unique
│  │  │     ├─ AvailableFilterButton (Button) unique
│  │  │     ├─ ActiveFilterButton (Button) unique
│  │  │     ├─ ReadyFilterButton (Button) unique
│  │  │     └─ CompletedFilterButton (Button) unique
│  │  ├─ ListPanel (PanelContainer)
│  │  │  └─ WeituoScroll (ScrollContainer) unique
│  │  │     └─ WeituoList (VBoxContainer) unique
│  │  └─ DetailPanel (PanelContainer)
│  │     └─ DetailVBox (VBoxContainer)
│  │        ├─ DetailTitle (Label) unique
│  │        ├─ DetailIssuer (Label) unique
│  │        ├─ DetailDesc (RichTextLabel) unique
│  │        ├─ RequirementList (VBoxContainer) unique
│  │        ├─ RewardList (VBoxContainer) unique
│  │        ├─ StateHint (Label) unique
│  │        └─ ActionButtons (HBoxContainer)
│  │           ├─ AcceptButton (TextureButton) unique
│  │           ├─ SubmitButton (TextureButton) unique
│  │           └─ AbandonButton (TextureButton) unique
│  └─ FooterHint (Label) unique
└─ ConfirmAbandonPopup (PanelContainer) unique
   ├─ ConfirmText (Label)
   ├─ CancelAbandonButton (Button)
   └─ ConfirmAbandonButton (Button)
```

所有 `unique` 节点在 `.tscn` 中设置 `unique_name_in_owner = true`，脚本用 `%NodeName` 访问。

### 5.2 `weituo_card.tscn`

```text
WeituoCard (Button / PanelContainer)
├─ Icon (TextureRect) unique
├─ TextBox (VBoxContainer)
│  ├─ TitleRow (HBoxContainer)
│  │  ├─ TitleLabel (Label) unique
│  │  └─ StateBadge (Label) unique
│  ├─ IssuerLabel (Label) unique
│  ├─ SummaryLabel (Label) unique
│  └─ ProgressBar (ProgressBar) unique
└─ RewardPreview (HBoxContainer) unique
```

卡片固定高度 `118`。标题最多一行，描述摘要最多两行，超出用省略或换详情面板展示。

### 5.3 行组件

`weituo_requirement_row.tscn`：

```text
RequirementRow (HBoxContainer)
├─ Icon (TextureRect) unique
├─ NameLabel (Label) unique
├─ CountLabel (Label) unique
└─ StatusLabel (Label) unique
```

奖励展示复用 `scenes/items/item.tscn` 或现有奖励展示逻辑，不再单独维护委托奖励行组件。

---

## 6. 视觉规范

### 6.1 风格

- 主色：米黄、浅棕、草绿，沿用背包和角色面板。
- 不使用纯黑、纯白、强霓虹色。
- 主面板可用现有 `StyleBoxFlat`：浅米底、棕色 3-5px 边框、少量阴影。
- 卡片边框区分状态，不新增复杂插画。

### 6.2 状态颜色

| 状态 | 标签文案 | 颜色建议 | 说明 |
|------|----------|----------|------|
| 可接受 | 可接 | 草绿 | 行动正向 |
| 进行中 | 进行中 | 棕黄 | 常规跟踪 |
| 可提交 | 可提交 | 亮绿 / 金色描边 | 最高优先级 |
| 条件不足 | 缺材料 | 灰棕 | 不能点 |
| 已完成 | 已完成 | 暗棕 | 降低注意 |

实现时若状态跨脚本复用，新增枚举文件：

```text
scripts/enum/enum_weituo_state.gd
class_name EnumWeituoState
enum State { LOCKED, AVAILABLE, ACTIVE, READY, COMPLETED }
```

---

## 7. 交互流程

### 7.1 首次打开

1. 默认筛选「全部」。
2. 列表按优先级排序：可提交 > 进行中 > 可接受 > 已完成。
3. 默认选中第一条可提交；没有则选中第一条进行中；再没有选中第一条可接。
4. 列表为空时显示空状态：`今日暂无合适委托。先修炼、巡山或整理背包。`

### 7.2 接受委托

点击「接受」：

- 若 active 未满：按钮变为进行中，详情刷新。
- 若 active 已满：`StateHint` 显示 `当前委托已满，先提交或放弃一项。`
- 不弹二次确认，接受不是破坏性操作。

### 7.3 提交委托

点击「提交」：

1. 再次检查条件。
2. 条件满足：扣交付物，发奖励，刷新列表。
3. 条件不满足：按钮置灰，缺口行高亮。

提交成功反馈：

- `StateHint`：`委托完成，奖励已收入背包。`
- 触发现有奖励 Tip。
- 可提交红点消失或更新。

### 7.4 放弃委托

点击「放弃」打开小确认框：

```text
放弃此委托？
当前进度会清空，但不会扣除道具。
[取消] [放弃]
```

v1 放弃不惩罚，不消耗时间。

### 7.5 关闭面板

- 点击关闭按钮关闭。
- Esc 关闭。
- 点击 Dimmer 不关闭，避免误触丢上下文。

---

## 8. 详情面板内容

### 8.1 字段顺序

1. 委托标题。
2. 发布者。
3. 类型标签：交付 / 历练。
4. 描述。
5. 需求。
6. 预定奖励。
7. 状态提示。
8. 操作按钮。

### 8.2 需求行文案

| 需求类型 | 文案格式 | 示例 |
|----------|----------|------|
| 道具交付 | `{物品名} {当前}/{需求}` | `灵草 4/6` |
| 历练地点 | `{地点名} {当前步数}/{目标步数}` | `青岚山脉 2/3 步` |
| 不战败 | `本次委托需未战败返程` | `未战败：已满足` |

### 8.3 奖励行文案

| 奖励类型 | 文案格式 |
|----------|----------|
| 灵石 | `灵石 x{count}` |
| 道具 | `{物品名} x{count}` |
| 装备 | `{装备名}` |

奖励预览必须和实际 `RewardService.apply_rewards()` 的结果同源，不在 UI 写死名称。

---

## 9. 筛选与排序

筛选：

- 全部
- 可接受
- 进行中
- 可提交
- 已完成

排序：

1. `READY`
2. `ACTIVE`
3. `AVAILABLE`
4. `COMPLETED`
5. `LOCKED` 默认不显示

同状态内排序：

1. 一次性委托在前。
2. 当前地点或当前城市相关在前。
3. 低境界委托在前。
4. 配置表顺序兜底。

---

## 10. 空状态与异常状态

| 情况 | UI 表现 | 按钮 |
|------|---------|------|
| 无委托 | 列表中部显示空文案 | 全部隐藏 |
| 配置加载失败 | `委托榜暂不可用` | 关闭可用 |
| active 满 | 接受按钮置灰，详情提示 | 可提交 / 放弃可用 |
| 背包不足 | 缺口需求行红棕高亮 | 提交置灰 |
| 奖励引用异常 | 该委托不显示 | 配置校验应先拦截 |

---

## 11. 键鼠与可访问性

- Esc：关闭面板或先关闭放弃确认框。
- 鼠标滚轮：滚动委托列表。
- Tab / Shift+Tab：在筛选、列表、按钮间切焦。
- Enter：触发当前主按钮；可提交优先提交，可接受优先接受。
- 所有按钮最小点击区 `44 x 44`。
- 列表滚动条始终可见或 hover 后明显，不隐藏到看不见。

---

## 12. 脚本边界

### `weituo_board_panel.gd`

职责：

- 请求 `WeituoService.visible_entries()`。
- 根据筛选刷新列表。
- 绑定选中项详情。
- 调用 `accept()`、`submit()`、`abandon()`。
- 更新按钮状态和提示文本。

不做：

- 不直接改 `GameState.inventory`。
- 不直接发奖励。
- 不动态创建固定结构节点，只实例化卡片和行组件。

### `weituo_card.gd`

职责：

- `bind(entry: Dictionary)`。
- 展示标题、发布者、摘要、状态、进度。
- 发出 `selected(instance_or_weituo_id)` 信号。

### 行组件脚本

只做 `bind(row: Dictionary)`，不查服务。

---

## 13. 数据绑定格式

UI 层接收服务整理后的展示数据，不直接深钻存档和配置。

```gdscript
{
	"key": "active:abc123",
	"weituo_id": "qinglan_herb_delivery_001",
	"state": EnumWeituoState.State.ACTIVE,
	"title": "采药急件",
	"issuer": "青石坊市药铺",
	"type_label": "交付",
	"summary": "灵草 4/6",
	"progress_ratio": 0.66,
	"requirements": [],
	"rewards": [],
	"can_accept": false,
	"can_submit": false,
	"can_abandon": true,
}
```

---

## 14. 新手与提示接入

委托系统不放进现有首章强制教程。首次自由游玩后可用轻提示：

- 第一次打开委托榜：`委托会给出预定奖励，接下后顺路完成即可。`
- 第一次可提交：`有委托已经完成，回道观提交可领取奖励。`

提示走现有 Tips 系统；不新增教程遮罩。

---

## 15. 验收清单

- 小道观能打开委托榜弹层，关闭后仍在小道观。
- `1280x800` 下三栏完整显示，文字不溢出按钮和卡片。
- 至少 2 个委托能正确显示：一个交付、一个历练。
- 可提交委托排在最前，并有明确高亮。
- 背包不足时提交按钮置灰，缺口行显示当前/需求数量。
- active 满时接受按钮置灰并显示原因。
- 放弃委托有确认框，取消不改变状态。
- 奖励预览使用现有物品 / 灵石图标，不写死错误名称。
- 所有脚本访问节点使用 `%NodeName`，需要访问的节点在 `.tscn` 设 `unique_name_in_owner = true`。
- 固定 UI 布局不在脚本里动态创建。

---

## 16. 暂不做

- 委托 NPC 立绘和对话。
- 委托地图定位跳转。
- 自动刷新动画。
- 批量接受 / 批量提交。
- 声望等级完整面板。

---

## 17. 变更记录

| 日期 | 变更摘要 |
|------|----------|
| 2026-06-28 | 新增委托系统 UI 设计文档：入口、三栏面板、节点树、状态、交互与验收 |
