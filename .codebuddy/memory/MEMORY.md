# 项目记忆

## 2026-07-09 - stackable 字段类型从 bool 改为 int
- `item_items.json` 和 `item_generated_learning_books.json` 中 `stackable` 字段: `true` → `1`, `false` → `0`
- `item_def.gd`: `stackable: bool` → `stackable: int`，默认值 `true` → `1`，判断 `not item.stackable` → `item.stackable == 0`
- `json_loader.gd`: `_build_generated_learning_book` 中 `bool(template.get("stackable", true))` → `int(template.get("stackable", 1))`
- `item_info_payload_builder.gd`: `def.stackable` → `def.stackable == 1`
