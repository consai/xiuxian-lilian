# 大道知识树

一套仿 EVE Online 技能训练逻辑、覆盖练气至渡劫的修仙知识系统。

- [完整设计规格](docs/大道知识树.md)
- [知识体系设计案](docs/知识体系设计案.md)
- [Godot 可直接读取的 JSON 配置](config/dao_tree.json)
- [功法 JSON 配置](config/cultivation_methods.json)
- [功法体系设计规格](docs/功法体系.md)
- [技能 JSON 配置](config/abilities.json)
- [技能体系设计规格](docs/技能体系.md)
- [1v5 多波战斗技能设计](docs/1v5多波战斗技能设计.md)
- [功法与技能配置规划方案](docs/功法与技能配置规划方案.md)
- [统一效果属性目录](config/effect_catalog.json)
- [一致性校验器](tools/dao/validate-dao-tree.mjs)

运行校验：

```powershell
npm run validate
# 或
.\tools\validate.ps1
# 单项
node tools/dao/validate-dao-tree.mjs
node tools/dao/validate-xiulian-methods.mjs
node tools/dao/validate-abilities.mjs
```

本项目只负责系统设计与配置交付，不包含游戏运行时代码。最终配置为 UTF-8 JSON，可由 Godot
使用 `FileAccess` 与 `JSON.parse_string()` 直接读取。每门知识均有稳定 ID、所属大道、境界门槛、
训练倍率和严格前置。
