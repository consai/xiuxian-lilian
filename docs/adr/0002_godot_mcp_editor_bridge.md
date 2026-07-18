# ADR 0002：Godot MCP 编辑器桥接

- 状态：接受
- 日期：2026-07-18
- 范围：本地 AI 工具访问 Godot 编辑器与运行中游戏

## 问题

需要让支持 MCP 的开发工具能够读取当前 Godot 编辑器状态、执行受控的场景检查和运行时验证，同时保持项目文件和运行时连接在本机范围内。

## 决定

1. 采用 `@satelliteoflove/godot-mcp` 4.1.0 作为 MCP 客户端桥接服务，通过项目级 `.codex/config.toml` 使用 `npx.cmd --yes` 启动。
2. 将插件安装在 `addons/godot_mcp/`，并在 `project.godot` 启用 `res://addons/godot_mcp/plugin.cfg`。
3. 允许插件登记 `MCPGameBridge` Autoload，用于运行中游戏的观察与输入；该 Autoload 不承载项目业务状态。
4. 插件只绑定 `127.0.0.1:6550`。MCP 工具默认采用 `writes` 审批模式，读操作可自动执行，写操作需获得批准。
5. MCP 服务器未连接或 Godot 编辑器未打开时，不影响游戏运行和普通无头测试；插件作为开发工具依赖，不进入发布包的业务逻辑。

## 替代方案

- 不接入 MCP：无法进行编辑器级场景检查和运行时验证，拒绝。
- 使用 Python/uv 方案：当前开发机没有 uv/Python，增加额外运行时安装和维护成本，暂不采用。
- 仅配置 MCP 服务器而不安装 Godot 插件：服务器无法连接编辑器，不能满足项目级验证需求，拒绝。

## 后果

- 首次启动 MCP 服务需要网络访问 npm registry；后续由 npm 缓存复用包。
- Godot 编辑器必须打开本项目且插件已启用，MCP 工具才能连接。
- 升级 MCP 包时必须同步检查插件兼容的 Godot 最低版本、工具审批策略和端口绑定，必要时更新本 ADR。
