---
description: Godot UI、状态与命名约定
globs: "**/*.{tscn,gd}"
alwaysApply: true
---

# 项目约定

- 固定 UI 写在 `.tscn`；脚本只做数据绑定、状态和信号。可复用 UI 建独立子场景，由主场景组合定位。
- 脚本访问的场景节点须设 `unique_name_in_owner = true`，以 `%NodeName` 获取，禁止硬编码节点路径。
- 可导航全屏/面板场景登记 `SceneManager.SCENE_PATHS`，经 `SceneManager.go_to()` 或对应 helper 进入；子场景、列表项与浮层 Host 可在所属脚本 `preload`/`instantiate`。
- 开发阶段不为假设中的旧数据或异常路径堆默认值、兼容与降级逻辑；数据或状态不合法时直接输出明确 `error`，尽早修复根因。
- 可复用离散业务类型放 `scripts/enum/enum_<snake>.gd`，以 `class_name Enum<Pascal>` 访问；局部 UI 状态可留在脚本内。
- 文件名小写下划线；中文业务词用拼音，通用技术/游戏术语可用英文。


# Production Architecture Baseline

完整规范见 [`docs/project_architecture_rules.md`](docs/project_architecture_rules.md)。本节是所有代码变更必须遵守的摘要；详细规则、脚本角色表、场景生命周期、存档协议和 CI 门禁以该文档为准。

## Architecture Rules

1. 依赖方向固定为 `presentation -> application -> domain/core`；`core` 禁止依赖具体功能模块。
2. UI 只能渲染快照、保存局部展示状态、发出用户意图；禁止直接访问或修改 `DataStore`、文件系统和业务规则。
3. 静态定义、长期状态、局内 session、UI 临时状态和缓存必须分离；状态必须有唯一所有者。
4. 跨模块、跨场景和存档边界使用 typed contract；模块内部不为每个函数创建 DTO。
5. 固定 UI、布局、Theme 和静态资源写入 `.tscn`；脚本只做节点绑定、状态绑定、信号和动画。动态数量节点才允许运行时实例化。
6. 场景节点访问必须使用 `unique_name_in_owner = true` 和 `%NodeName`；禁止硬编码 NodePath、`/root` 查找和散落 `change_scene*()`。
7. 可导航页面统一由 `SceneManager` 管理；页面失败时保留旧页面，禁止导航器执行业务结算、奖励或存档。
8. Domain 必须脱离 SceneTree、Node、Autoload 和 FileAccess 独立运行；只有需要生命周期的对象才继承 `Node`。
9. 新脚本必须匹配明确角色：`*_application`、`*_service`、`*_state`、`*_session`、`*_catalog`、`*_repository`、`*_contract`、`*_view`、`*_page`、`*_dialog`、`*_host`、`*_presenter`、`*_validator`、`*_migration`、`enum_*` 等；禁止新增万能 `manager/helper/utils/common`。
10. 配置、存档和资源错误必须返回明确错误或在开发/CI 中 fail-fast；禁止静默 `{}`、`null`、默认假数据或分散 fallback。
11. 存档必须有连续 schema migration、临时文件、备份和原子替换；不得保存 Node、Resource 实例、Texture、Callable 或绝对路径。
12. 新增 Autoload、改变依赖方向、改变存档/配置格式或建立长期例外，必须先写 `docs/adr/NNNN_<title>.md`。

