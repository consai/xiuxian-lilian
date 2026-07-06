class_name EnumMajorRealm
extends RefCounted

## 大境界 id（拼音）与显示名，与 dao_tree.realms / jingjie_balance.major_realms 一致。

enum Type {
	LIANQI = 1,
	ZHUJI = 2,
	JINDAN = 3,
	YUANYING = 4,
	HUASHEN = 5,
	LIANXU = 6,
	HETI = 7,
	DACHENG = 8,
	DUJIE = 9,
}

const ID_LIANQI := "lianqi"
const ID_ZHUJI := "zhuji"
const ID_JINDAN := "jindan"
const ID_YUANYING := "yuanying"
const ID_HUASHEN := "huashen"
const ID_LIANXU := "lianxu"
const ID_HETI := "heti"
const ID_DACHENG := "dacheng"
const ID_DUJIE := "dujie"

const LABEL_LIANQI := "练气"
const LABEL_ZHUJI := "筑基"
const LABEL_JINDAN := "金丹"
const LABEL_YUANYING := "元婴"
const LABEL_HUASHEN := "化神"
const LABEL_LIANXU := "炼虚"
const LABEL_HETI := "合体"
const LABEL_DACHENG := "大乘"
const LABEL_DUJIE := "渡劫"

const ORDERED_IDS: Array[String] = [
	ID_LIANQI,
	ID_ZHUJI,
	ID_JINDAN,
	ID_YUANYING,
	ID_HUASHEN,
	ID_LIANXU,
	ID_HETI,
	ID_DACHENG,
	ID_DUJIE,
]

const LABELS_BY_ID: Dictionary = {
	ID_LIANQI: LABEL_LIANQI,
	ID_ZHUJI: LABEL_ZHUJI,
	ID_JINDAN: LABEL_JINDAN,
	ID_YUANYING: LABEL_YUANYING,
	ID_HUASHEN: LABEL_HUASHEN,
	ID_LIANXU: LABEL_LIANXU,
	ID_HETI: LABEL_HETI,
	ID_DACHENG: LABEL_DACHENG,
	ID_DUJIE: LABEL_DUJIE,
}

## 旧英文 id → 拼音 id（读档/旧配置兼容）。
const LEGACY_ID_MAP: Dictionary = {
	"lianqi": ID_LIANQI,
	"zhuji": ID_ZHUJI,
	"jindan": ID_JINDAN,
	"yuanying": ID_YUANYING,
	"huashen": ID_HUASHEN,
	"lianxu": ID_LIANXU,
	"heti": ID_HETI,
	"dacheng": ID_DACHENG,
	"tribulation": ID_DUJIE,
}

const TRANSITION_BY_MAJOR: Dictionary = {
	ID_LIANQI: "lianqi_to_zhuji",
	ID_ZHUJI: "zhuji_to_jindan",
	ID_JINDAN: "jindan_to_yuanying",
}

## 大境界突破品质存档键（筑基/金丹/元婴）。
const BREAKTHROUGH_QUALITY_REALMS: Array[String] = [ID_ZHUJI, ID_JINDAN, ID_YUANYING]


static func default_id() -> String:
	return ID_LIANQI


static func normalize_id(realm_id: String) -> String:
	var rid := realm_id.strip_edges().to_lower()
	if LABELS_BY_ID.has(rid):
		return rid
	return str(LEGACY_ID_MAP.get(rid, rid))


static func is_valid_id(realm_id: String) -> bool:
	return LABELS_BY_ID.has(normalize_id(realm_id))


static func label(realm_id: String) -> String:
	var rid := normalize_id(realm_id)
	return str(LABELS_BY_ID.get(rid, rid))


static func order(realm_id: String) -> int:
	var rid := normalize_id(realm_id)
	var index := ORDERED_IDS.find(rid)
	return index + 1 if index >= 0 else 0


static func realm_id_for_tier(tier: int) -> String:
	var index := clampi(tier, Type.LIANQI, Type.DUJIE) - 1
	if index < 0 or index >= ORDERED_IDS.size():
		return ID_LIANQI
	return ORDERED_IDS[index]


static func tier_for_realm_id(realm_id: String) -> int:
	var rid := normalize_id(realm_id)
	var index := ORDERED_IDS.find(rid)
	if index < 0:
		return Type.LIANQI
	return index + 1
