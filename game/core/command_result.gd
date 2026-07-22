class_name CommandResult extends RefCounted

## Outcome of a command issued to GameSession.
## Mirrors the three-state result required by ADR-0005
## (transactional: OK / FAIL / REJECTED).

enum Status {OK, FAIL, REJECTED}

const _PATH: String = "res://game/core/command_result.gd"

var status: int = Status.OK
var message: String = ""
var data: Dictionary = {}

func _init(p_status: int = Status.OK, p_message: String = "", p_data: Dictionary = {}) -> void:
	status = p_status
	message = p_message
	data = p_data

static func ok(p_message: String = "", p_data: Dictionary = {}) -> CommandResult:
	return CommandResult.new(Status.OK, p_message, p_data)

static func fail(p_message: String = "", p_data: Dictionary = {}) -> CommandResult:
	return CommandResult.new(Status.FAIL, p_message, p_data)

static func rejected(p_message: String = "", p_data: Dictionary = {}) -> CommandResult:
	return CommandResult.new(Status.REJECTED, p_message, p_data)

func to_dict() -> Dictionary:
	return {
		"status": status,
		"message": message,
		"data": data.duplicate(true),
	}

static func from_dict(d: Dictionary) -> CommandResult:
	var status_value: int = int(d.get("status", Status.OK))
	var message_value: String = String(d.get("message", ""))
	var data_value: Dictionary = {}
	var raw_data: Variant = d.get("data", {})
	if typeof(raw_data) == TYPE_DICTIONARY:
		data_value = (raw_data as Dictionary).duplicate(true)
	return CommandResult.new(status_value, message_value, data_value)

func is_ok() -> bool:
	return status == Status.OK

func is_fail() -> bool:
	return status == Status.FAIL

func is_rejected() -> bool:
	return status == Status.REJECTED