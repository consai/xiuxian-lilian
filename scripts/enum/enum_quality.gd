class_name EnumQuality
extends RefCounted

const QUALITY_COLORS: Dictionary = {
	1: Color.WHITE,
	2: Color.YELLOW,
	3: Color.RED,
	4: Color.PINK,
	5: Color.BLUE,
	6: Color.GREEN,
	7: Color.ORANGE,
	8: Color.PURPLE,
}

# 获取品质颜色
static func get_color(quality: int) -> Color:
	var color: Color = QUALITY_COLORS.get(quality)
	if color == null:
		push_error("EnumQuality: 品质颜色不存在")
		return Color.WHITE
	return color


 
