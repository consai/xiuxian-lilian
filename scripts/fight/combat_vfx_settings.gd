class_name CombatVfxSettings
extends Resource

## 战斗表现全局可调参数（挂到 [FightVfxManager] 或各 [CombatActorVfx] 上覆盖）。

@export_group("待机呼吸")
## 角色固定基准缩放（rest_scale = (x, x)）；不使用运行时动态快照缩放。
@export_range(0.5, 4.0) var actor_base_scale: float = 1.8
## 空闲时是否播放循环呼吸动画。
@export var idle_enabled: bool = true
## 呼吸缩放下限（相对原始 scale）。
@export_range(0.9, 1.1) var idle_scale_min: float = 1.0
## 呼吸缩放上限（相对原始 scale）。
@export_range(0.9, 1.15) var idle_scale_max: float = 1.03
## 上下悬浮幅度（像素）。
@export_range(0.0, 24.0) var idle_float_amplitude: float = 4.0
## 呼吸频率（次/秒）。
@export_range(0.1, 4.0) var idle_frequency_hz: float = 0.85
## 呼吸缓动曲线类型。
@export var idle_transition: Tween.TransitionType = Tween.TRANS_SINE
## 呼吸缓动进出方式。
@export var idle_ease: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("近战攻击")
## 蓄力阶段后撤距离（像素）。
@export_range(4.0, 80.0) var melee_windup_offset: float = 22.0
## 蓄力阶段时长（秒）。
@export_range(0.05, 0.5) var melee_windup_duration: float = 0.14
## 蓄力位移缓动曲线。
@export var melee_windup_trans: Tween.TransitionType = Tween.TRANS_QUAD
## 蓄力位移缓动方式。
@export var melee_windup_ease: Tween.EaseType = Tween.EASE_OUT
## 蓄力压扁时 X 轴缩放倍率。
@export_range(0.8, 1.4) var melee_squash_scale_x: float = 1.12
## 蓄力压扁时 Y 轴缩放倍率。
@export_range(0.5, 1.0) var melee_squash_scale_y: float = 0.82
## 冲锋阶段时长（秒）。
@export_range(0.02, 0.2) var melee_dash_duration: float = 0.08
## 冲锋位移缓动曲线。
@export var melee_dash_trans: Tween.TransitionType = Tween.TRANS_EXPO
## 冲锋位移缓动方式。
@export var melee_dash_ease: Tween.EaseType = Tween.EASE_IN
## 停在目标前方的间距（像素，沿攻击方向）。
@export_range(0.0, 120.0) var melee_strike_inset: float = 48.0
## 弹回原位阶段时长（秒）。
@export_range(0.1, 0.6) var melee_return_duration: float = 0.22
## 弹回位移缓动曲线。
@export var melee_return_trans: Tween.TransitionType = Tween.TRANS_QUAD
## 弹回位移缓动方式。
@export var melee_return_ease: Tween.EaseType = Tween.EASE_OUT

@export_group("远程攻击")
## 后坐力后撤距离（像素）。
@export_range(4.0, 60.0) var ranged_recoil_offset: float = 14.0
## 后坐力阶段时长（秒）。
@export_range(0.05, 0.4) var ranged_recoil_duration: float = 0.1
## 后坐力缓动曲线。
@export var ranged_recoil_trans: Tween.TransitionType = Tween.TRANS_SINE
## 后坐力缓动方式。
@export var ranged_recoil_ease: Tween.EaseType = Tween.EASE_OUT
## 释放前挺时长（秒，此瞬间发射弹道）。
@export_range(0.02, 0.25) var ranged_release_duration: float = 0.07
## 释放挺出缓动曲线。
@export var ranged_release_trans: Tween.TransitionType = Tween.TRANS_BACK
## 释放挺出缓动方式。
@export var ranged_release_ease: Tween.EaseType = Tween.EASE_IN
## 回位阶段时长（秒）。
@export_range(0.05, 0.5) var ranged_settle_duration: float = 0.16
## 回位缓动曲线。
@export var ranged_settle_trans: Tween.TransitionType = Tween.TRANS_QUAD
## 回位缓动方式。
@export var ranged_settle_ease: Tween.EaseType = Tween.EASE_OUT
## 弹道飞行时长（秒）。
@export_range(0.1, 1.5) var projectile_travel_duration: float = 0.35
## 弹道位移缓动曲线。
@export var projectile_trans: Tween.TransitionType = Tween.TRANS_LINEAR
## 弹道位移缓动方式。
@export var projectile_ease: Tween.EaseType = Tween.EASE_IN_OUT
## 贝塞尔弹道弧高（像素，0 为直线）。
@export_range(0.0, 200.0) var projectile_arc_height: float = 36.0
## 是否使用二次贝塞尔曲线飞行（关闭则为直线）。
@export var projectile_use_bezier: bool = true

@export_group("受击反馈")
## 受击瞬间形变时长（秒）。
@export_range(0.02, 0.2) var hit_squash_duration: float = 0.05
## 受击形变恢复时长（秒）。
@export_range(0.1, 0.5) var hit_recover_duration: float = 0.2
## 受击形变缓动曲线。
@export var hit_squash_trans: Tween.TransitionType = Tween.TRANS_BACK
## 受击形变缓动方式。
@export var hit_squash_ease: Tween.EaseType = Tween.EASE_OUT
## 沿攻击方向的拉伸倍率。
@export_range(0.5, 1.5) var hit_stretch_along_dir: float = 1.18
## 垂直攻击方向的压扁倍率。
@export_range(0.4, 1.0) var hit_squash_perpendicular: float = 0.78
## 受击后退距离（像素）。
@export_range(0.0, 40.0) var hit_knockback_distance: float = 14.0
## 受击后退时长（秒）。
@export_range(0.02, 0.15) var hit_knockback_duration: float = 0.06
## 受击左右抖动总时长（秒）。
@export_range(0.05, 0.35) var hit_shake_duration: float = 0.14
## 受击抖动幅度（像素）。
@export_range(0.0, 16.0) var hit_shake_amplitude: float = 5.0
## 受击抖动频率（越高越密）。
@export_range(8.0, 48.0) var hit_shake_frequency: float = 28.0
## 普通受击闪色（modulate，可大于 1 提亮）。
@export var hit_flash_color: Color = Color(1.35, 0.35, 0.35, 1.0)
## 暴击受击闪色。
@export var hit_crit_flash_color: Color = Color(2.0, 2.0, 2.0, 1.0)
## 闪色切入时长（秒）。
@export_range(0.02, 0.2) var hit_flash_in_duration: float = 0.04
## 闪色淡出时长（秒）。
@export_range(0.05, 0.4) var hit_flash_out_duration: float = 0.16
## 闪色淡出缓动曲线。
@export var hit_flash_trans: Tween.TransitionType = Tween.TRANS_SINE
## 闪色淡出缓动方式。
@export var hit_flash_ease: Tween.EaseType = Tween.EASE_OUT

@export_group("暴击震屏")
## 暴击时屏幕/场景抖动幅度（像素）。
@export_range(0.0, 24.0) var crit_shake_amplitude: float = 10.0
## 暴击震屏总时长（秒）。
@export_range(0.05, 0.5) var crit_shake_duration: float = 0.22
## 暴击震屏频率（越高越密）。
@export_range(10.0, 60.0) var crit_shake_frequency: float = 36.0
## 震屏缓动曲线。
@export var crit_shake_trans: Tween.TransitionType = Tween.TRANS_SINE
## 震屏缓动方式。
@export var crit_shake_ease: Tween.EaseType = Tween.EASE_OUT
