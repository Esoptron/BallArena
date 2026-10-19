extends "res://scripts/game_launcher.gd"
var campaign: Control
func _ready() -> void:
	super._ready()
	front_menu.connect("campaign_requested",_open_campaign)
func _open_campaign() -> void:
	front_menu.hide(); front_menu.process_mode=Node.PROCESS_MODE_DISABLED
	if not is_instance_valid(campaign):
		campaign=load("res://scripts/campaign/controller.gd").new()
		front_menu.get_parent().add_child(campaign)
		campaign.connect("closed",_close_campaign)
	else: campaign.process_mode=Node.PROCESS_MODE_INHERIT; campaign.show(); campaign.call("show_page","levels")
func _close_campaign() -> void:
	campaign.hide(); campaign.process_mode=Node.PROCESS_MODE_DISABLED
	front_menu.process_mode=Node.PROCESS_MODE_INHERIT; front_menu.show(); front_menu.show_page("modes")
func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(campaign) and campaign.visible:
		if event.is_action_pressed("ui_cancel"): campaign.call("back"); get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)
