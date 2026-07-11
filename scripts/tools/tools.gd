extends Node
class_name Tools

## 公共接口函数集合（全局工具）。
## 可作为 AutoLoad 单例使用；函数亦为静态方法，可直接 Tools.xxx() 调用。

const ART_ROOT := "res://assets/art/"

static var _texture_cache: Dictionary = {}


## 图片加载接口：传入名称，返回加载的 Texture2D（带缓存）。
## name 支持三种形式：
##   1. 完整路径，如 "res://assets/art/ui_new/hudun_icon.png"
##   2. 相对 ART_ROOT 的路径，如 "ui_new/hudun_icon.png"
##   3. 文件名（含扩展名），自动在 ART_ROOT 下递归搜索
static func load_image(name: String) -> Texture2D:
	var path := _resolve_image_path(name)
	if path == "":
		push_warning("Tools.load_image: 无法解析图片名称 '%s'" % name)
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var res := ResourceLoader.load(path)
	if res is Texture2D:
		_texture_cache[path] = res
		return res as Texture2D
	push_warning("Tools.load_image: 加载失败 '%s'" % path)
	return null


static func _resolve_image_path(name: String) -> String:
	var n := name.strip_edges()
	if n == "":
		return ""
	if n.begins_with("res://"):
		return n
	var full := ART_ROOT + n
	if ResourceLoader.exists(full):
		return full
	return ""
