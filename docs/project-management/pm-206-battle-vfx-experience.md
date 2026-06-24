# PM-206：战斗特效体验版设计细化

版本：v0.2  
日期：2026-06-24  
状态：设计细化，待实现与手动验收

## 1. 目标

让玩家在不读战斗日志的情况下，也能看懂一次出手的三件事：

- 谁出手。
- 打向谁。
- 造成了伤害、护盾、治疗、持续伤害或状态变化中的哪一种结果。

本期只做“体验版”，不做完整粒子库、音效系统、镜头演出库或高阶技能专属动画。

## 2. 现有基础

已存在的可复用基础：

- VFX 调度：`scripts/fight/fight_vfx_manager.gd`
- 动作序列：`scripts/fight/vfx`
- 预设配置：`data/combat/presets`
- 预设索引：`data/combat/vfx_index.yaml`
- 浮字样式：`data/combat/float_styles.yaml`
- 战斗表现衔接：`scripts/fight/scene/fight_scene_presentation.gd`

当前已有表现：

- `melee_default`：近战蓄力、冲锋、受击、回位。
- `ranged_default`：后坐、释放、弹道、受击。
- `status_cast`：状态类施法动作。
- `hit_default`：受击形变、击退、闪色、抖动。
- `hit_only`：仅受击。

## 3. 设计原则

- 先读结果，再看酷炫：伤害、治疗、护盾、状态浮字必须比动作更清楚。
- 同类复用，少做专属：本期按技能类型分，不给每个技能做独立动画。
- 不挡关键 UI：特效范围限制在角色与战场中线，不遮挡血条、行动条、战斗日志。
- 节奏短：一次普通技能表现目标为 `[PLACEHOLDER] 0.35-0.75 秒`，只作为首测假设。
- 可降级：低配模式优先关震屏、曲线弹道、待机呼吸，再退到浮字和血条变化。

## 4. 玩家体验规格

### 4.1 普攻 / 近战

目的：让普通攻击有“贴近、命中、退回”的身体感，避免像数值瞬移。

玩家感受：角色主动压上去，敌人被击中并短暂后仰。

输入：

- `vfx_type: "melee"`。
- 或未配置 `vfx_type` 且没有 `ranged / spell / magic` 标签。

输出：

- 播放 `melee_default`。
- 命中帧触发 `hit_default`。
- 伤害浮字使用 `damage` 或 `crit`。

成功标准：

- 施法者移动方向与目标一致。
- 命中反馈发生在角色接近目标后。
- 暴击时可额外震屏，但不能让血条难读。

失败态：

- 角色 VFX 未注册时，跳过位移动作，但血条、浮字、日志仍正常更新。
- 目标死亡时，本次表现播完后再进入结算，不中途丢姿势。

调参杠杆：

- `CombatVfxSettings.melee_*`
- `CombatVfxSettings.hit_*`
- `CombatVfxSettings.crit_*`
- `data/combat/float_styles.yaml` 的 `damage / crit`

### 4.2 弹道 / 法术远程

目的：让远程技能和普攻区分开，玩家能看到“术法飞过去”。

玩家感受：施法者短暂蓄势，飞行物抵达后目标受击。

输入：

- `vfx_type: "ranged"`。
- 或技能标签包含 `ranged / spell / magic`。
- 当前代表技能：`御气弹`、`破空剑气`。

输出：

- 播放 `ranged_default`。
- 弹道抵达后触发 `hit_default`。
- 技能名浮字先出现，伤害浮字在目标上方出现。

成功标准：

- 弹道起点来自施法者附近，终点落在目标附近。
- 弹道不穿过血条区和战斗日志区。
- 远程技能看起来比近战更“轻”，不要有贴脸冲锋。

失败态：

- 弹道节点创建失败时，直接播 `hit_only` 或只保留伤害浮字。
- 低配模式关闭贝塞尔曲线，改直线弹道。

调参杠杆：

- `CombatVfxSettings.ranged_*`
- `CombatVfxSettings.projectile_*`
- `CombatProjectileVfx.visual_size`
- `CombatProjectileVfx.visual_color`

### 4.3 护盾 / 防御状态

目的：让玩家看懂“这次不是打人，而是在保命”。

玩家感受：角色向内收势，身上出现短促护体反馈，随后护盾值或护盾浮字变化。

输入：

- `vfx_type: "buff"` 或 `vfx_type: "shield"`。
- 技能效果含 `shield`。
- 当前代表技能：`流风步`，法宝代表：`寒潭珠`。

输出：

- 本期优先复用 `status_cast`。
- 新增配置时可建 `shield_cast.yaml`，只用现有 `tween / wait / modulate` 能力，不加新系统。
- 浮字使用 `shield`。
- 护盾条同步更新。

成功标准：

- 护盾反馈出现在自己身上，不打到敌人身上。
- 护盾浮字与护盾条变化同屏可读。
- 没有受击抖动，避免误读成受到攻击。

失败态：

- 若无法识别 `shield`，回退 `status_cast` 加 `shield` 浮字。
- 低配模式保留护盾浮字和护盾条，跳过身体动作。

调参杠杆：

- `status_cast` 或 `shield_cast.yaml`
- `data/combat/float_styles.yaml` 的 `shield`
- `CombatVfxSettings.ranged_recoil_*` 可复用为施法收势

### 4.4 治疗 / 回蓝

目的：让恢复行为和伤害行为明显反色、反方向，避免玩家以为又被打了。

玩家感受：使用丹药或恢复技能时，自己身上出现上升的绿色 / 蓝色反馈。

输入：

- `vfx_type: "heal"`。
- 道具或技能效果含 `heal / restore_mp`。
- 当前代表道具：`疗伤丹`、`回气丹`、`回灵丹`。

输出：

- 本期复用 `status_cast`。
- 治疗浮字使用 `heal`。
- 回蓝浮字使用 `mp_gain`。
- 不触发目标受击、不震屏。

成功标准：

- 治疗数字为正向表达，如 `+30`。
- 回蓝和治疗颜色不同。
- 角色不后退、不被击退。

失败态：

- 恢复值为 0 时，不产生恢复浮字。
- 若恢复和伤害同帧出现，伤害优先级更高，但恢复仍可通过错层显示。

调参杠杆：

- `data/combat/float_styles.yaml` 的 `heal / mp_gain`
- `status_cast`

### 4.5 持续伤害 / 灼烧

目的：让玩家知道不是新的一次主动攻击，而是状态在结算。

玩家感受：目标身上周期性跳出较小的负面数字，并带状态名。

输入：

- `buff.tick_effects` 中含 `type: "damage"`。
- 当前代表状态：`buff_dot`，显示名 `灼烧`。

输出：

- 不播放完整施法动作。
- 使用 `CombatFloatPresenter.build_buff_tick_spawns()` 生成状态名与伤害。
- 可选新增 `dot_tick.yaml`，只做轻微闪色或短促抖动。

成功标准：

- 玩家能区分“灼烧跳伤”和“敌人又打了一下”。
- 跳伤不打断当前行动节奏。
- 多次跳伤不会盖住主要伤害浮字。

失败态：

- 同帧浮字过多时，保留伤害数字，状态名可被节流。
- 低配模式只显示浮字，不播放 `dot_tick`。

调参杠杆：

- `data/combat/float_styles.yaml` 的 `buff_add / damage`
- `CombatFloatLayer.max_per_unit_per_frame`
- 可选 `dot_tick.yaml`

## 5. 最小实现清单

### 必做

- 给首版常用技能 / 道具补明确 `vfx_type` 或 `vfx` 绑定：
  - `御气弹`：`ranged_default`
  - `破空剑气`：`ranged_default`
  - `流风步`：`status_cast` 或 `shield_cast`
  - 战斗丹药：`status_cast`
  - `buff_dot` 跳伤：浮字优先，必要时 `hit_only`
- 确认 `FightScenePresentation.vfx_type_from_cfg()` 对 `heal / buff / shield` 不误判成近战。
- 确认浮字优先级：暴击伤害 > 普通伤害 > 状态新增 / 治疗 / 护盾 > 技能名。
- 低配降级先用现有参数：
  - `idle_enabled = false`
  - `projectile_use_bezier = false`
  - `crit_shake_amplitude = 0`

### 可选

- 新增 `shield_cast.yaml`：短促收势 + 自身提亮 + 回待机。
- 新增 `dot_tick.yaml`：目标轻微闪色，不击退。
- 新增 `heal_cast.yaml`：自身提亮，不移动。

## 6. 不做内容

- 不新增粒子编辑器或粒子资源库。
- 不新增音效。
- 不做每个技能的专属动画。
- 不扩充高阶技能视觉。
- 不把战斗表现逻辑写进领域结算层。

## 7. UI 遮挡规则

- 特效节点应挂在战斗角色层或现有 projectile parent，不挂到 HUD 顶层。
- 浮字层继续使用 `CombatFloatLayer`，不要直接把 Label 动态塞进战斗主场景。
- 血条、行动条、战斗日志必须始终在视觉上可读。
- 弹道飞行路径只允许穿过中间战场区域；若实际截图显示遮挡，优先降低弧高或改直线。

## 8. 验收用例

手动验收一场普通战，至少覆盖：

- 普攻：敌我任一方普攻能看到近战靠近、受击、回位。
- 弹道：`御气弹` 或 `破空剑气` 有飞行物，抵达后再受击。
- 护盾：`流风步` 后自己出现护盾浮字，护盾条变化。
- 治疗：使用治疗丹药后自己出现治疗浮字，不触发敌人受击。
- 持续伤害：`灼烧` 跳伤时显示状态相关浮字，不播放完整施法。
- 暴击：暴击浮字更醒目，震屏不影响读血条。
- 低配：关闭待机 / 曲线弹道 / 震屏后，战斗仍可读。

## 9. 破坏标准

出现以下任一情况，PM-206 不通过：

- 玩家无法区分普攻、弹道、护盾、治疗、持续伤害。
- 特效遮挡血条、行动条或战斗日志。
- 一个普通技能表现明显拖慢战斗节奏，超过 `[PLACEHOLDER] 1.0 秒`。
- VFX 报错导致战斗逻辑无法继续。
- 低配降级后缺少关键结果反馈。

## 10. 测试建议

- 配置校验：确保新增 preset 文件能被 `CombatVfxPresetLibrary` 找到。
- Headless 冒烟：跑战斗域测试，确认表现配置不影响结算。
- 手动截图：普通战、弹道、护盾、治疗、DOT、低配各截一张。

## 11. 静态图落地方案

用户已在 `assets/art/effect` 准备静态特效图。本期不做序列帧，先把静态图接入现有 projectile 管线。

### 11.1 资源用途

| 文件 | 首版用途 | 说明 |
| --- | --- | --- |
| `assets/art/effect/image_cutout_194x82.png` | `御气弹` 弹道 | 长条金色飞行物，适合基础灵力弹。 |
| `assets/art/effect/image_cutout_167x69.png` | 飞剑 / 高速剑气弹道 | 更窄更锐，适合 `破空剑气` 的飞剑感。 |
| `assets/art/effect/image_cutout_180x124.png` | 剑气命中感参考 | 月牙形，首版可暂不接；若飞剑不够明显，再用于剑系 impact。 |
| `assets/art/effect/image_cutout_171x116.png` | 命中爆点参考 | 首版可暂不接；后续统一 impact sprite 时使用。 |
| `assets/art/effect/image_cutout_173x125.png` | 护盾 / 施法旋涡参考 | 首版可暂不接；护盾先用 `status_cast` + `shield` 浮字。 |
| `assets/art/effect/image_cutout_182x128.png` | 暴击 / 强命中参考 | 首版可暂不接；避免暴击表现过亮遮挡血条。 |

### 11.2 最小代码改动

只改现有三处：

- `scripts/fight/combat_projectile_vfx.gd`：把当前 `ColorRect` 占位弹道扩展为可选 `Texture2D`。无贴图时继续走 `ColorRect` fallback。
- `scripts/fight/vfx/combat_action_executor.gd`：让 `op: "projectile"` 读取 step 上的 `texture`、`visual_size`、`rotation_offset_deg`、`use_bezier`。
- `data/combat/presets`：新增两个 projectile preset，不新增管理器。

不新增内容：

- 不做序列帧播放器。
- 不做粒子系统。
- 不做新的 VFX registry。
- 不重写 `FightVfxManager`。

### 11.3 新增 preset

新增 `data/combat/presets/qi_bolt_projectile.yaml`：

```yaml
_comment: "御气弹：施法动作 + 金色弹道 + 受击"
sequence:
  - op: "stop_idle"
    actor: "caster"
  - op: "tween"
    actor: "caster"
    prop: "position"
    to:
      anchor: "recoil"
    duration_key: "ranged.recoil_duration"
    trans_key: "ranged.recoil_trans"
    ease_key: "ranged.recoil_ease"
  - op: "parallel"
    steps:
      - op: "sequence"
        steps:
          - op: "tween"
            actor: "caster"
            prop: "position"
            to:
              anchor: "rest"
            duration_key: "ranged.settle_duration"
            trans_key: "ranged.settle_trans"
            ease_key: "ranged.settle_ease"
          - op: "resume_idle"
            actor: "caster"
      - op: "sequence"
        steps:
          - op: "projectile"
            texture: "res://assets/art/effect/image_cutout_194x82.png"
            visual_size: [80, 34]
            rotation_offset_deg: 0
          - op: "impact"
```

新增 `data/combat/presets/sword_qi_projectile.yaml`：

```yaml
_comment: "破空剑气：高速飞剑 / 剑气弹道 + 受击"
sequence:
  - op: "stop_idle"
    actor: "caster"
  - op: "tween"
    actor: "caster"
    prop: "position"
    to:
      anchor: "recoil"
    duration: 0.06
    trans: "sine"
    ease: "out"
  - op: "parallel"
    steps:
      - op: "sequence"
        steps:
          - op: "tween"
            actor: "caster"
            prop: "position"
            to:
              anchor: "rest"
            duration: 0.12
            trans: "quad"
            ease: "out"
          - op: "resume_idle"
            actor: "caster"
      - op: "sequence"
        steps:
          - op: "projectile"
            texture: "res://assets/art/effect/image_cutout_167x69.png"
            visual_size: [88, 36]
            rotation_offset_deg: 0
            use_bezier: false
          - op: "impact"
```

### 11.4 技能绑定

在 `data/abilities.yaml` 只给首版常用技能补绑定：

```yaml
# 御气弹
vfx:
  preset: "qi_bolt_projectile"

# 破空剑气
vfx:
  preset: "sword_qi_projectile"
```

`流风步`、丹药、DOT 暂不绑静态图：

- `流风步`：继续 `status_cast` + 护盾浮字。
- 丹药：继续 `status_cast` + 治疗 / 回蓝浮字。
- `灼烧`：继续 DOT 浮字，不播完整动作。

### 11.5 验收顺序

1. `御气弹` 能看到金色弹道飞向敌人。
2. `破空剑气` 看起来比 `御气弹` 更快、更窄、更像飞剑。
3. 两者抵达后才触发受击。
4. 没有贴图或贴图路径错误时，弹道回退为原 `ColorRect`，战斗不中断。
5. 低配关闭贝塞尔后，`御气弹` 和 `破空剑气` 仍可读。

### 11.6 追加判断

如果静态弹道接入后仍不够区分，再加一个通用 `sprite_flash` op，用同一套逻辑在目标或自身位置短暂显示静态图。那时再接 `image_cutout_180x124.png`、`image_cutout_171x116.png`、`image_cutout_173x125.png`。首版先不加。

## 12. 变更记录

| 日期 | 版本 | 内容 |
| --- | --- | --- |
| 2026-06-24 | v0.2 | 补充 `assets/art/effect` 静态图用途、最小代码改动、两个 projectile preset 与技能绑定方案。 |
| 2026-06-24 | v0.1 | 根据 PM-206 看板、现有 VFX 管线和 GameDesigner 规范细化体验目标、类型规格、验收与最小实现清单。 |
