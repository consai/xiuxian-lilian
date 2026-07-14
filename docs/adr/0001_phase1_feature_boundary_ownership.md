# ADR 0001：Phase 1 功能边界与所有权迁移

- 状态：接受
- 日期：2026-07-13
- 范围：Phase 1 core 反向依赖清零、配置按需化与模块公开边界

## 问题

现有 `scripts/core` 同时持有通用基础设施和炼丹、委托、角色、战斗、地图等功能的状态默认值、配置缓存、归一化及业务类型。这使 `core` 依赖具体功能模块，`ConfigManager`/`JsonLoader` 启动时装载多张功能表，也让 UI、战斗对象和场景导航通过全局节点取得功能数据。

生产规范要求依赖方向固定为 `presentation -> application -> domain/core`，配置按单表按需读取，状态和静态定义具有唯一所有者；Phase 1 退出条件还要求 core 反向依赖为零。

## 决定

1. `scripts/core` 只保留通用 JSON/文件读取、存档协议、导航机制和不含具体玩法语义的基础类型。
2. 功能静态配置迁到所属模块的 `*_catalog`，采用惰性读取、整表 schema/reference 校验、稳定错误和深拷贝查询；跨表现层查询通过所属模块的 application API 暴露。
3. 角色、炼丹、委托等长期状态的默认值和当前 schema 校验迁到所属 feature 的 `*_state`；`DataStore` 只负责中性快照、schema/migration 和原子导入，功能引用在提交前由所属 application/service 校验。
4. 战斗对象所需的 Buff 等静态定义由应用边界按 session 显式注入，不通过 SceneTree、Autoload 或 Catalog 反查，也不进入存档。
5. 地图、历练事件、道具、装备、技能等配置按独立切片从 `ConfigManager`/`JsonLoader` 迁出；不保留永久转发层。受玩家可见行为歧义影响的切片必须按执行协议暂停裁决。
6. 含战斗语义的公开 contract 归 `features/battle/contracts`，不得通过在 core 复制业务常量来掩盖依赖。
7. `ARCH-001` 最终以零容忍门禁检查 core 对功能脚本、功能 `class_name`、功能 Autoload 和功能配置路径的引用；只允许 `SceneManager` 路由注册表这一精确角色例外，不建立债务基线。

## 替代方案

- 保留 `ConfigManager` 转发到新 Catalog：会维持全局服务耦合和启动预加载，拒绝。
- 把功能常量或 Adapter 复制进 core：会产生双权威并掩盖依赖方向，拒绝。
- 一次性重写全部配置与状态：风险过大且难以刻画行为，拒绝；采用有最小可运行检查的串行切片。
- 为旧存档和坏配置保留 fallback：产品已决定不兼容旧存档，且规范要求 fail-fast，拒绝。

## 后果

- `ConfigManager`、`JsonLoader` 和 `DataStore` 的公开 API 会逐批删除；每批必须先列调用者并同步测试。
- feature 之间只通过明确 application/contract 边界协作，Catalog 和 domain 私有实现不得被 presentation 直接访问。
- 当前存档 schema 版本和受保护 Excel/导出 JSON 不因这些结构迁移而改变。
- 每个切片必须保持已完成玩法结果和主要 UI 行为；若正确解析现有配置会改变玩家可见结果，必须暂停请求产品决定。
- Phase 1 完成前需运行统一 `npm.cmd run validate`，并证明 `ARCH-001` 为零。
