class_name SoundBankManager
extends RefCounted

## Central Manager for loading, unloading, caching and streaming monolithic SoundBanks.

const SoundBankClass = preload("res://addons/opendou/runtime/soundbank.gd")

var loaded_banks: Dictionary = {} # StringName -> SoundBank

## Loads a sound bank file and caches it by name.
func load_bank(file_path: String, bank_name: StringName = &"") -> SoundBank:
	var b_name: StringName = bank_name
	if b_name.is_empty():
		b_name = StringName(file_path.get_file().get_basename())
		
	if loaded_banks.has(b_name):
		return loaded_banks[b_name]
		
	var bank = SoundBankClass.new(file_path, b_name)
	if bank.load_from_file(file_path):
		loaded_banks[b_name] = bank
		return bank
	return null

## Unloads a sound bank and releases its RAM prefetch block and file handle.
func unload_bank(bank_name: StringName) -> void:
	if loaded_banks.has(bank_name):
		var bank: SoundBank = loaded_banks[bank_name]
		bank.close()
		loaded_banks.erase(bank_name)

## Retrieves a loaded sound bank by name.
func get_bank(bank_name: StringName) -> SoundBank:
	if loaded_banks.has(bank_name):
		return loaded_banks[bank_name]
	return null

## Unloads all soundbanks.
func clear_all() -> void:
	for b_name in loaded_banks:
		var bank: SoundBank = loaded_banks[b_name]
		bank.close()
	loaded_banks.clear()
