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

## 配置
- 仅按需读取单个 `data/*.yaml` 或 `data/exportjson/**/*.json`，禁止批量加载。
