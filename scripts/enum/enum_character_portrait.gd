class_name EnumCharacterPortrait
extends RefCounted

## 首批正式角色立绘路径；icon 字段与 ZhandouInitData 共用 assets/art/ 前缀约定。

const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")

const PATH_PLAYER := "characters/001_cutout_483x512.png"
const PATH_FOX := "characters/003_cutout_407x512.png"
const PATH_MASTER := "characters/004_cutout_502x512.png"
const PATH_CORGI := "characters/005_cutout_311x512.png"
const PATH_GATHERER := "characters/006_cutout_427x512.png"

# 剧情说话人 -> 立绘（首批占位；节点可显式 portrait 覆盖）
const SPEAKER_PORTRAITS: Dictionary = {
	"小观主": PATH_PLAYER,
	"炼丹小札": PATH_MASTER,
	"雾溪采药人": PATH_GATHERER,
}

# 怪物 id -> 立绘（敌人临时复用角色图，后续可拆独立怪物美术）
const MONSTER_PORTRAITS: Dictionary = {
	"qinglan_wolf": PATH_FOX,
	"ironback_bear": PATH_CORGI,
	"qinglan_serpent": PATH_GATHERER,
	"qinglan_boss": PATH_CORGI,
	"poison_marsh_serpent": PATH_FOX,
	"rot_armor_crocodile": PATH_MASTER,
	"mist_marten": PATH_FOX,
	"vine_armor_guard": PATH_CORGI,
	"sealed_creek_boss": PATH_MASTER,
}


static func texture(path: String) -> Texture2D:
	var trimmed := path.strip_edges()
	if trimmed == "":
		return null
	return ZhandouInitDataScript._resolve_icon_texture({"icon": trimmed})


static func portrait_for_speaker(speaker: String) -> String:
	return str(SPEAKER_PORTRAITS.get(speaker.strip_edges(), ""))


static func portrait_for_monster(monster_id: String) -> String:
	return str(MONSTER_PORTRAITS.get(monster_id.strip_edges(), PATH_FOX))


static func assert_assets_loadable() -> void:
	for path in [PATH_PLAYER, PATH_FOX, PATH_MASTER, PATH_CORGI, PATH_GATHERER]:
		assert(texture(path) != null, "角色立绘缺失: %s" % path)
