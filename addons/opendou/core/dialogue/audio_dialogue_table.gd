@tool
class_name AudioDialogueTable
extends Resource

## Database mapping abstract dialogue keys (e.g. &"HERO_ATTACK_01") to locale-specific audio streams or assets.

## Structure:
## {
##   &"HERO_ATTACK_01": { "en": stream_en, "es": stream_es, "ja": stream_ja },
##   &"NPC_QUEST_INTRO": { "en": stream_en, "es": stream_es, "ja": stream_ja }
## }
@export var entries: Dictionary = {}

func add_entry(dialogue_key: StringName, lang_code: String, stream_asset: Variant) -> void:
	if not entries.has(dialogue_key):
		entries[dialogue_key] = {}
	entries[dialogue_key][lang_code.to_lower()] = stream_asset

func get_stream(dialogue_key: StringName, lang_code: String, fallback_lang: String = "en") -> Variant:
	if not entries.has(dialogue_key):
		return null
		
	var dict = entries[dialogue_key]
	var lang_low = lang_code.to_lower()
	if dict.has(lang_low):
		return dict[lang_low]
	elif dict.has(fallback_lang.to_lower()):
		return dict[fallback_lang.to_lower()]
	elif not dict.is_empty():
		return dict.values()[0]
	return null

func get_all_keys() -> Array[StringName]:
	var res: Array[StringName] = []
	for k in entries.keys():
		res.append(k)
	return res
