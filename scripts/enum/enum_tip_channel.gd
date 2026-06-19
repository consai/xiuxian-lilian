class_name EnumTipChannel
extends RefCounted

enum Channel {
	BAR,
	COMBAT_BLOCK,
	REWARD_ITEM,
	REWARD_GROWTH,
	REWARD_RESOURCE,
}

const LABEL_BAR := "bar"
const LABEL_COMBAT_BLOCK := "combat_block"
const LABEL_REWARD_ITEM := "reward_item"
const LABEL_REWARD_GROWTH := "reward_growth"
const LABEL_REWARD_RESOURCE := "reward_resource"

const VALID_LABELS: Array[String] = [
	LABEL_BAR,
	LABEL_COMBAT_BLOCK,
	LABEL_REWARD_ITEM,
	LABEL_REWARD_GROWTH,
	LABEL_REWARD_RESOURCE,
]


static func label(channel: Channel) -> String:
	match channel:
		Channel.COMBAT_BLOCK:
			return LABEL_COMBAT_BLOCK
		Channel.REWARD_ITEM:
			return LABEL_REWARD_ITEM
		Channel.REWARD_GROWTH:
			return LABEL_REWARD_GROWTH
		Channel.REWARD_RESOURCE:
			return LABEL_REWARD_RESOURCE
		_:
			return LABEL_BAR


static func from_label(text: String) -> Channel:
	match text.strip_edges():
		LABEL_COMBAT_BLOCK:
			return Channel.COMBAT_BLOCK
		LABEL_REWARD_ITEM:
			return Channel.REWARD_ITEM
		LABEL_REWARD_GROWTH:
			return Channel.REWARD_GROWTH
		LABEL_REWARD_RESOURCE:
			return Channel.REWARD_RESOURCE
		_:
			return Channel.BAR


static func is_valid_label(text: String) -> bool:
	return text.strip_edges() in VALID_LABELS


static func is_reward_channel(text: String) -> bool:
	return text.strip_edges() in [
		LABEL_REWARD_ITEM,
		LABEL_REWARD_GROWTH,
		LABEL_REWARD_RESOURCE,
	]
