extends Control

const AudioSynth = preload("res://scripts/audio_synth.gd")
const PLAYFIELD = Rect2(Vector2(120.0, 150.0), Vector2(1360.0, 660.0))
const BASE_PADDLE_WIDTH = 170.0
const PADDLE_HEIGHT = 24.0
const BALL_RADIUS = 10.0
const SAVE_PATH = "user://progress.cfg"

const BRICK_META = {
	"A": {"hits": 1, "color": Color("27d8ff"), "highlight": Color("b3f9ff"), "points": 110, "glow": Color("27d8ff", 0.75)},
	"B": {"hits": 1, "color": Color("ff5dcb"), "highlight": Color("ffd0f2"), "points": 120, "glow": Color("ff5dcb", 0.75)},
	"C": {"hits": 1, "color": Color("ffe262"), "highlight": Color("fff7be"), "points": 130, "glow": Color("ffe262", 0.75)},
	"D": {"hits": 2, "color": Color("8cff72"), "highlight": Color("d6ffc4"), "points": 170, "glow": Color("8cff72", 0.78)},
	"E": {"hits": 2, "color": Color("ff9640"), "highlight": Color("ffd2ab"), "points": 190, "glow": Color("ff9640", 0.8)},
	"S": {"hits": 3, "color": Color("8aa2ff"), "highlight": Color("eef1ff"), "points": 260, "glow": Color("8aa2ff", 0.8)},
	"X": {"hits": 1, "color": Color("ff4646"), "highlight": Color("ffd0d0"), "points": 320, "glow": Color("ff4646", 0.88), "explosive": true}
}

const POWERUP_META = {
	"wide": {"label": "W", "title": "Sugar Stretch", "color": Color("33f0ff"), "weight": 16.0, "duration": 14.0},
	"multi": {"label": "M", "title": "Mirrorball", "color": Color("ff66cb"), "weight": 13.0},
	"laser": {"label": "L", "title": "Lollipop Laser", "color": Color("ffe666"), "weight": 11.0, "duration": 12.0},
	"catch": {"label": "C", "title": "Candy Catch", "color": Color("85ff70"), "weight": 11.0, "duration": 12.0},
	"slow": {"label": "S", "title": "Sugar Slow", "color": Color("9dd2ff"), "weight": 10.0, "duration": 11.0},
	"heart": {"label": "H", "title": "Heart", "color": Color("ffffff"), "weight": 7.0},
	"nova": {"label": "N", "title": "Neon Nova", "color": Color("ff914a"), "weight": 7.0},
	"bomb": {"label": "B", "title": "Bomb Slow", "color": Color("ff4c86"), "weight": 10.0, "duration": 8.0, "bad": true}
}

const LEVELS = [
	{
		"name": "Candy Crown",
		"tagline": "Open the vault",
		"background": [Color("16052e"), Color("3b1174"), Color("0bb6ff")],
		"stripe": Color("ff57c8", 0.18),
		"layout": [
			"......ABCCBA......",
			".....ABCDDCBA.....",
			"....ABCDDXXDCBA...",
			"...ABCDESSSEDCBA..",
			"..ABCDESSSSEDCBA..",
			".ABCDDDEEEEDDDCBA.",
			"ABCCDDEDDDEDDCCBA.",
			"ABCCDDEDDDEDDCCBA.",
			".ABCDDDEEEEDDDCBA.",
			"..AABBCCDDCCBBA..."
		]
	},
	{
		"name": "Prism Pulse",
		"tagline": "Surf the sugar storm",
		"background": [Color("081633"), Color("1d4bcf"), Color("ff4fbe")],
		"stripe": Color("8dfff3", 0.18),
		"layout": [
			"AA..BB..CC..DD..EE",
			".AA..BB..CC..DD..E",
			"..AA..BB..CC..DD..",
			"...AA..BB..CC..D..",
			"SSSAAABBXXCCCDDSSS",
			"...DD..CC..BB..A..",
			"..DD..CC..BB..AA..",
			".DD..CC..BB..AA...",
			"EE..DD..CC..BB..AA",
			"..SS..EE..XX..SS.."
		]
	},
	{
		"name": "Sugar Serpent",
		"tagline": "Bite through the coil",
		"background": [Color("16071f"), Color("4e0f57"), Color("ff7d39")],
		"stripe": Color("ffe06f", 0.16),
		"layout": [
			"....AABBCCDDEE....",
			"...AABBDDSSDDEE...",
			"..AABBXXSSXXDDEE..",
			".AABBCCDDEECCDDEE.",
			"AABBDD......DDEEA.",
			".DDEE..AABB..AABB.",
			"..DDEECCDDEECCBB..",
			"...DDEESSSSEECC...",
			"....CCDDEECCBB....",
			".....BBCCDDCC....."
		]
	},
	{
		"name": "Nova Teeth",
		"tagline": "Stay out of the jaws",
		"background": [Color("061627"), Color("062f4d"), Color("17d8b5")],
		"stripe": Color("ff6ed1", 0.15),
		"layout": [
			"XX..SS..XX..SS..XX",
			".XX..SSXXSS..XX..S",
			"..XX..SSSS..XX..S.",
			"...XX..SS..XX..S..",
			"AAAAAABBBBCCCCDDDD",
			"DDDDCCCCBBBBAAAAAA",
			"...S..XX..SS..XX..",
			"..S..XX..SSSS..XX.",
			".S..XX..SSXXSS..XX",
			"XX..SS..XX..SS..XX"
		]
	},
	{
		"name": "Candy Cataclysm",
		"tagline": "Empty the store",
		"background": [Color("1a0430"), Color("6a117e"), Color("ffd34d")],
		"stripe": Color("42f5ff", 0.16),
		"layout": [
			"ABCDEEDCBAABCDEEDC",
			"BCDESSDECBBCDESSDE",
			"CDEXXSXEDCCDEXXSXE",
			"DEESSSSEDDDEESSSSE",
			"EESSDDSSEEEESSDDSS",
			"XSSDEEDSSXXSSDEEDS",
			"EESSDDSSEEEESSDDSS",
			"DEESSSSEDDDEESSSSE",
			"CDEXXSXEDCCDEXXSXE",
			"BCDESSDECBBCDESSDE",
			"ABCDEEDCBAABCDEEDC"
		]
	}
]

var rng = RandomNumberGenerator.new()
var paddle = {}
var balls: Array = []
var bricks: Array = []
var powerups: Array = []
var particles: Array = []
var lasers: Array = []
var floaters: Array = []
var active_effects = {}
var score = 0
var high_score = 0
var lives = 3
var level_index = 0
var combo_multiplier = 1
var combo_clock = 0.0
var state = "title"
var state_timer = 0.0
var paused_from_state = "playing"
var menu_context = "title"
var options_open = false
var title_phase = 0.0
var banner_text = ""
var banner_timer = 0.0
var overlay_message = ""
var overlay_subtitle = ""
var screen_shake = 0.0
var screen_flash = 0.0
var flash_color = Color.WHITE
var camera_offset = Vector2.ZERO
var laser_cooldown = 0.0
var last_paddle_x = PLAYFIELD.get_center().x
var current_level_name = ""
var run_won = false
var settings = {
	"speed": 5,
	"cheat": false,
	"music": true,
	"sfx": true,
	"volume": 0.75
}
var music_player: AudioStreamPlayer
var sfx_players: Array = []
var sfx_index = 0
var audio_streams = {}

var score_label: Label
var level_label: Label
var lives_label: Label
var combo_label: Label
var banner_label: Label
var title_label: Label
var subtitle_label: Label
var powers_label: Label
var pause_button: Button
var menu_panel: PanelContainer
var menu_title_label: Label
var menu_hint_label: Label
var buttons_box: VBoxContainer
var primary_button: Button
var secondary_button: Button
var options_button: Button
var exit_button: Button
var back_button: Button
var options_box: VBoxContainer
var speed_value_label: Label
var speed_slider: HSlider
var cheat_toggle: CheckButton
var music_toggle: CheckButton
var sfx_toggle: CheckButton
var volume_value_label: Label
var volume_slider: HSlider


func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_input_actions()
	_load_progress()
	_build_audio()
	_build_ui()
	_start_new_game()
	state = "title"
	menu_context = "title"
	_update_overlay()
	_refresh_menu_ui()
	_ensure_music_state()
	_refresh_ui()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_ui()


func _ensure_input_actions() -> void:
	_bind_key_action("move_left", KEY_A)
	_bind_key_action("move_left", KEY_LEFT)
	_bind_key_action("move_right", KEY_D)
	_bind_key_action("move_right", KEY_RIGHT)
	_bind_key_action("launch", KEY_SPACE)
	_bind_key_action("launch", KEY_ENTER)
	_bind_key_action("launch", KEY_W)
	_bind_key_action("shoot", KEY_F)
	_bind_key_action("pause", KEY_ESCAPE)
	_bind_key_action("pause", KEY_P)
	_bind_key_action("cheat_skip", KEY_N)
	_bind_key_action("cheat_ball", KEY_B)
	_bind_mouse_action("launch", MOUSE_BUTTON_LEFT)


func _bind_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var key_event = InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)


func _bind_mouse_action(action: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button_index:
			return
	var mouse_event = InputEventMouseButton.new()
	mouse_event.button_index = button_index
	InputMap.action_add_event(action, mouse_event)


func _build_audio() -> void:
	audio_streams = AudioSynth.create_sfx_library()
	audio_streams["music"] = AudioSynth.create_music_stream()

	music_player = AudioStreamPlayer.new()
	music_player.stream = audio_streams["music"]
	add_child(music_player)

	for _index in range(10):
		var sfx_player = AudioStreamPlayer.new()
		add_child(sfx_player)
		sfx_players.append(sfx_player)

	_update_audio_mix()


func _build_ui() -> void:
	score_label = _make_label(28, Color("fff2d1"), HORIZONTAL_ALIGNMENT_LEFT)
	level_label = _make_label(24, Color("d9f6ff"), HORIZONTAL_ALIGNMENT_CENTER)
	lives_label = _make_label(28, Color("fff2d1"), HORIZONTAL_ALIGNMENT_RIGHT)
	combo_label = _make_label(22, Color("ffd967"), HORIZONTAL_ALIGNMENT_CENTER)
	banner_label = _make_label(34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title_label = _make_label(62, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label = _make_label(22, Color("ffe9ff"), HORIZONTAL_ALIGNMENT_CENTER)
	powers_label = _make_label(18, Color("bffbff"), HORIZONTAL_ALIGNMENT_LEFT)

	add_child(score_label)
	add_child(level_label)
	add_child(lives_label)
	add_child(combo_label)
	add_child(banner_label)
	add_child(title_label)
	add_child(subtitle_label)
	add_child(powers_label)
	_build_menu_ui()

	_layout_ui()


func _make_label(font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label = Label.new()
	label.label_settings = LabelSettings.new()
	label.label_settings.font_size = font_size
	label.label_settings.font_color = color
	label.label_settings.outline_color = Color(0.03, 0.02, 0.08, 0.85)
	label.label_settings.outline_size = 7
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_menu_ui() -> void:
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_on_pause_button_pressed)
	add_child(pause_button)

	menu_panel = PanelContainer.new()
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.visible = true
	add_child(menu_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	menu_panel.add_child(margin)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	menu_title_label = _make_label(32, Color("fff8c8"), HORIZONTAL_ALIGNMENT_CENTER)
	menu_title_label.custom_minimum_size = Vector2(420, 40)
	content.add_child(menu_title_label)

	menu_hint_label = _make_label(18, Color("dff8ff"), HORIZONTAL_ALIGNMENT_CENTER)
	menu_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_hint_label.custom_minimum_size = Vector2(420, 56)
	content.add_child(menu_hint_label)

	buttons_box = VBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 10)
	content.add_child(buttons_box)

	primary_button = _make_menu_button("Play")
	primary_button.pressed.connect(_on_primary_button_pressed)
	buttons_box.add_child(primary_button)

	secondary_button = _make_menu_button("Restart Run")
	secondary_button.pressed.connect(_on_secondary_button_pressed)
	buttons_box.add_child(secondary_button)

	options_button = _make_menu_button("Options")
	options_button.pressed.connect(_on_options_button_pressed)
	buttons_box.add_child(options_button)

	exit_button = _make_menu_button("Exit")
	exit_button.pressed.connect(_on_exit_button_pressed)
	buttons_box.add_child(exit_button)

	options_box = VBoxContainer.new()
	options_box.visible = false
	options_box.add_theme_constant_override("separation", 8)
	content.add_child(options_box)

	var speed_row = _make_slider_row("Speed", 1.0, 10.0, 1.0)
	speed_value_label = speed_row["value"]
	speed_slider = speed_row["slider"]
	speed_slider.value_changed.connect(_on_speed_changed)
	options_box.add_child(speed_row["row"])

	cheat_toggle = _make_check_button("Cheat mode")
	cheat_toggle.toggled.connect(_on_cheat_toggled)
	options_box.add_child(cheat_toggle)

	music_toggle = _make_check_button("Music")
	music_toggle.toggled.connect(_on_music_toggled)
	options_box.add_child(music_toggle)

	sfx_toggle = _make_check_button("Sound effects")
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	options_box.add_child(sfx_toggle)

	var volume_row = _make_slider_row("Volume", 0.0, 100.0, 1.0)
	volume_value_label = volume_row["value"]
	volume_slider = volume_row["slider"]
	volume_slider.value_changed.connect(_on_volume_changed)
	options_box.add_child(volume_row["row"])

	back_button = _make_menu_button("Back")
	back_button.pressed.connect(_on_back_button_pressed)
	content.add_child(back_button)

	_sync_settings_controls()


func _make_menu_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 42)
	button.focus_mode = Control.FOCUS_ALL
	return button


func _make_check_button(text: String) -> CheckButton:
	var button = CheckButton.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 34)
	return button


func _make_slider_row(title: String, min_value: float, max_value: float, step: float) -> Dictionary:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var head = HBoxContainer.new()
	var name_label = _make_label(16, Color("fff6d0"), HORIZONTAL_ALIGNMENT_LEFT)
	name_label.text = title
	name_label.custom_minimum_size = Vector2(240, 24)
	head.add_child(name_label)
	var value_label = _make_label(16, Color("c0f6ff"), HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size = Vector2(100, 24)
	head.add_child(value_label)
	row.add_child(head)
	var slider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(360, 24)
	row.add_child(slider)
	return {"row": row, "slider": slider, "value": value_label}


func _sync_settings_controls() -> void:
	if speed_slider == null:
		return
	speed_slider.value = settings["speed"]
	speed_value_label.text = "%d" % int(settings["speed"])
	cheat_toggle.button_pressed = settings["cheat"]
	music_toggle.button_pressed = settings["music"]
	sfx_toggle.button_pressed = settings["sfx"]
	volume_slider.value = round(float(settings["volume"]) * 100.0)
	volume_value_label.text = "%d%%" % int(volume_slider.value)


func _layout_ui() -> void:
	if score_label == null:
		return
	score_label.position = Vector2(44, 30)
	score_label.size = Vector2(520, 50)
	level_label.position = Vector2(size.x * 0.5 - 260, 26)
	level_label.size = Vector2(520, 56)
	lives_label.position = Vector2(size.x - 420, 30)
	lives_label.size = Vector2(360, 50)
	combo_label.position = Vector2(size.x * 0.5 - 210, PLAYFIELD.end.y + 18)
	combo_label.size = Vector2(420, 36)
	powers_label.position = Vector2(48, PLAYFIELD.end.y + 18)
	powers_label.size = Vector2(600, 80)
	banner_label.position = Vector2(size.x * 0.5 - 340, 96)
	banner_label.size = Vector2(680, 48)
	title_label.position = Vector2(size.x * 0.5 - 420, size.y * 0.28)
	title_label.size = Vector2(840, 88)
	subtitle_label.position = Vector2(size.x * 0.5 - 420, size.y * 0.28 + 92)
	subtitle_label.size = Vector2(840, 150)
	pause_button.position = Vector2(size.x - 176, 96)
	pause_button.size = Vector2(120, 38)
	menu_panel.position = Vector2(size.x * 0.5 - 240, size.y * 0.5 - 220)
	menu_panel.size = Vector2(480, 440)


func _game_speed_scale() -> float:
	return 0.55 + float(settings["speed"]) * 0.09


func _max_lives() -> int:
	return 9 if settings["cheat"] else 5


func _refresh_menu_ui() -> void:
	if menu_panel == null:
		return

	var menu_visible = state in ["title", "paused", "game_over"] or options_open
	menu_panel.visible = menu_visible
	buttons_box.visible = not options_open
	options_box.visible = options_open
	back_button.visible = options_open
	pause_button.visible = state in ["serve", "playing", "paused"]
	pause_button.text = "Resume" if state == "paused" else "Pause"

	if options_open:
		menu_title_label.text = "Options"
		menu_hint_label.text = "Speed, cheat mode, pause-safe toggles, and audio controls."
		primary_button.visible = false
		secondary_button.visible = false
		options_button.visible = false
		exit_button.visible = true
		exit_button.text = "Exit Game"
		return

	primary_button.visible = true
	options_button.visible = true
	exit_button.visible = true
	back_button.visible = false

	match state:
		"title":
			menu_title_label.text = "Candy Breakout Bombast"
			menu_hint_label.text = "Play immediately, or tweak a few arcade options first."
			primary_button.text = "Play"
			secondary_button.visible = false
			options_button.text = "Options"
			exit_button.text = "Exit"
		"paused":
			menu_title_label.text = "Paused"
			menu_hint_label.text = "Resume, restart the run, or change options."
			primary_button.text = "Resume"
			secondary_button.visible = true
			secondary_button.text = "Restart Run"
			options_button.text = "Options"
			exit_button.text = "Exit"
		"game_over":
			menu_title_label.text = "Set Complete" if run_won else "Game Over"
			menu_hint_label.text = "Best score is saved locally. Start another run or adjust options."
			primary_button.text = "Play Again"
			secondary_button.visible = false
			options_button.text = "Options"
			exit_button.text = "Exit"
		_:
			menu_title_label.text = ""
			menu_hint_label.text = ""
			primary_button.visible = false
			secondary_button.visible = false
			options_button.visible = false
			exit_button.visible = false



func _open_options() -> void:
	options_open = true
	_sync_settings_controls()
	_refresh_menu_ui()
	_play_sfx("menu")


func _close_options() -> void:
	options_open = false
	_refresh_menu_ui()
	_play_sfx("menu")


func _pause_game() -> void:
	if state not in ["serve", "playing"]:
		return
	paused_from_state = state
	state = "paused"
	state_timer = 0.0
	menu_context = "paused"
	options_open = false
	_refresh_menu_ui()
	_ensure_music_state()
	_play_sfx("pause")


func _resume_game() -> void:
	if state != "paused":
		return
	state = paused_from_state
	state_timer = 0.0
	options_open = false
	_refresh_menu_ui()
	_ensure_music_state()
	_play_sfx("menu")


func _toggle_pause() -> void:
	if options_open and state == "paused":
		_close_options()
		return
	if state == "paused":
		_resume_game()
	else:
		_pause_game()


func _build_db(multiplier: float) -> float:
	return linear_to_db(max(multiplier, 0.0001))


func _update_audio_mix() -> void:
	if music_player == null:
		return
	var volume = float(settings["volume"])
	music_player.volume_db = _build_db(volume * 0.5)
	for player in sfx_players:
		player.volume_db = _build_db(volume * 0.8)


func _ensure_music_state() -> void:
	if music_player == null:
		return
	_update_audio_mix()
	if not settings["music"]:
		music_player.stop()
		music_player.stream_paused = false
		return
	if state == "paused":
		music_player.stream_paused = true
		return
	music_player.stream_paused = false
	if not music_player.playing:
		music_player.play()


func _play_sfx(name: String, pitch_scale: float = 1.0) -> void:
	if not settings["sfx"]:
		return
	if not audio_streams.has(name) or sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = sfx_players[sfx_index % sfx_players.size()]
	sfx_index += 1
	player.stop()
	player.stream = audio_streams[name]
	player.pitch_scale = pitch_scale
	player.play()


func _on_pause_button_pressed() -> void:
	_toggle_pause()


func _on_primary_button_pressed() -> void:
	match state:
		"title", "game_over":
			_start_new_game()
			state = "serve"
			state_timer = 0.0
			menu_context = ""
			options_open = false
			_play_sfx("menu")
		"paused":
			_resume_game()
	_refresh_menu_ui()


func _on_secondary_button_pressed() -> void:
	_start_new_game()
	state = "serve"
	state_timer = 0.0
	menu_context = ""
	options_open = false
	_play_sfx("menu")
	_refresh_menu_ui()


func _on_options_button_pressed() -> void:
	_open_options()


func _on_back_button_pressed() -> void:
	_close_options()


func _on_exit_button_pressed() -> void:
	_play_sfx("pause")
	get_tree().quit()


func _on_speed_changed(value: float) -> void:
	settings["speed"] = int(value)
	speed_value_label.text = "%d" % int(value)
	_save_progress()


func _on_cheat_toggled(enabled: bool) -> void:
	settings["cheat"] = enabled
	_save_progress()
	_play_sfx("menu")


func _on_music_toggled(enabled: bool) -> void:
	settings["music"] = enabled
	_save_progress()
	_ensure_music_state()
	_play_sfx("menu")


func _on_sfx_toggled(enabled: bool) -> void:
	settings["sfx"] = enabled
	_save_progress()
	if enabled:
		_play_sfx("menu")


func _on_volume_changed(value: float) -> void:
	settings["volume"] = value / 100.0
	volume_value_label.text = "%d%%" % int(value)
	_save_progress()
	_update_audio_mix()


func _start_new_game() -> void:
	score = 0
	lives = 7 if settings["cheat"] else 3
	level_index = 0
	active_effects.clear()
	run_won = false
	combo_multiplier = 1
	combo_clock = 0.0
	options_open = false
	menu_context = ""
	_load_level(level_index)


func _load_level(index: int) -> void:
	level_index = clamp(index, 0, LEVELS.size() - 1)
	var level = LEVELS[level_index]
	current_level_name = "%s | %s" % [level["name"], level["tagline"]]
	bricks.clear()
	powerups.clear()
	particles.clear()
	lasers.clear()
	floaters.clear()
	active_effects.clear()
	laser_cooldown = 0.0
	options_open = false

	var layout: Array = level["layout"]
	var column_count = 18
	var brick_size = Vector2(64.0, 28.0)
	var gap = Vector2(6.0, 6.0)
	var grid_width = column_count * brick_size.x + (column_count - 1) * gap.x
	var origin = Vector2(PLAYFIELD.get_center().x - grid_width * 0.5, PLAYFIELD.position.y + 54.0)

	for row in range(layout.size()):
		var line: String = layout[row]
		for column in range(line.length()):
			var key: String = line[column]
			if key == "." or not BRICK_META.has(key):
				continue
			var meta: Dictionary = BRICK_META[key]
			var rect = Rect2(
				origin + Vector2(column * (brick_size.x + gap.x), row * (brick_size.y + gap.y)),
				brick_size
			)
			bricks.append(
				{
					"rect": rect,
					"hits_left": meta["hits"],
					"max_hits": meta["hits"],
					"color": meta["color"],
					"highlight": meta["highlight"],
					"glow": meta["glow"],
					"points": meta["points"],
					"explosive": meta.get("explosive", false),
					"alive": true
				}
			)

	paddle = {
		"pos": Vector2(PLAYFIELD.get_center().x, PLAYFIELD.end.y - 44.0),
		"width": BASE_PADDLE_WIDTH,
		"height": PADDLE_HEIGHT,
		"target_width": BASE_PADDLE_WIDTH,
		"vx": 0.0
	}
	last_paddle_x = paddle["pos"].x
	balls.clear()
	balls.append(_make_ball(Vector2(paddle["pos"].x, paddle["pos"].y - 26.0), Vector2.ZERO, true))
	state = "serve"
	state_timer = 0.0
	banner_text = level["name"]
	banner_timer = 2.0
	_flash(Color("ffffff", 0.65), 0.35)
	_shake(8.0)
	_ensure_music_state()
	_refresh_ui()
	_refresh_menu_ui()
	_update_overlay()


func _make_ball(position: Vector2, velocity: Vector2, stuck: bool) -> Dictionary:
	return {
		"pos": position,
		"prev": position,
		"vel": velocity,
		"radius": BALL_RADIUS,
		"stuck": stuck,
		"trail": [],
		"tint": Color.WHITE
	}


func _process(delta: float) -> void:
	title_phase += delta
	state_timer += delta
	_update_overlay()
	_ensure_music_state()
	var world_delta = delta * _game_speed_scale()
	if state != "paused":
		_update_effects(delta)
		_update_paddle(delta)
		_update_powerups(world_delta)
		_update_lasers(world_delta)
		_update_particles(world_delta)
		_update_floaters(world_delta)

	if state == "playing":
		_update_balls(world_delta)
	elif state == "serve":
		_update_stuck_balls()
	elif state == "level_clear" and state_timer > 1.5:
		if level_index < LEVELS.size() - 1:
			lives = min(lives + 1, _max_lives())
			_save_progress()
			_play_sfx("level_clear")
			_load_level(level_index + 1)
		else:
			run_won = true
			state = "game_over"
			state_timer = 0.0
			menu_context = "game_over"
			_save_progress()
			_play_sfx("game_over")

	if combo_clock > 0.0:
		combo_clock -= delta
		if combo_clock <= 0.0:
			combo_multiplier = 1
	if banner_timer > 0.0:
		banner_timer -= delta

	screen_shake = move_toward(screen_shake, 0.0, delta * 18.0)
	screen_flash = move_toward(screen_flash, 0.0, delta * 2.6)
	camera_offset = Vector2(
		rng.randf_range(-screen_shake, screen_shake),
		rng.randf_range(-screen_shake, screen_shake)
	)

	_refresh_menu_ui()
	_refresh_ui()
	queue_redraw()


func _update_paddle(delta: float) -> void:
	var target_width = BASE_PADDLE_WIDTH
	if active_effects.has("wide"):
		target_width *= 1.55
	paddle["target_width"] = clamp(target_width, 92.0, 320.0)
	var movement_slow = 0.38 if active_effects.has("bomb") else 1.0
	paddle["width"] = lerp(float(paddle["width"]), float(paddle["target_width"]), 1.0 - pow(0.001, delta * movement_slow))

	var move_strength = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var target_x = paddle["pos"].x
	if abs(move_strength) > 0.01:
		target_x += move_strength * 1080.0 * delta * movement_slow
	elif Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		target_x = get_local_mouse_position().x
	target_x = clamp(target_x, PLAYFIELD.position.x + paddle["width"] * 0.5, PLAYFIELD.end.x - paddle["width"] * 0.5)
	paddle["pos"].x = lerp(float(paddle["pos"].x), target_x, 1.0 - pow(0.0001, delta * movement_slow))
	paddle["vx"] = (paddle["pos"].x - last_paddle_x) / max(delta, 0.001)
	last_paddle_x = paddle["pos"].x


func _update_stuck_balls() -> void:
	for ball in balls:
		if not ball["stuck"]:
			continue
		ball["pos"] = Vector2(paddle["pos"].x, paddle["pos"].y - 24.0)
		ball["prev"] = ball["pos"]
		_push_ball_trail(ball)


func _update_balls(delta: float) -> void:
	var survivors: Array = []
	for ball in balls:
		if ball["stuck"]:
			ball["pos"] = Vector2(paddle["pos"].x, paddle["pos"].y - 24.0)
			ball["prev"] = ball["pos"]
			_push_ball_trail(ball)
			survivors.append(ball)
			continue

		var lost = false
		var distance = ball["vel"].length() * delta
		var steps = max(1, int(ceil(distance / 18.0)))
		var step_delta = delta / float(steps)
		for _step in range(steps):
			ball["prev"] = ball["pos"]
			ball["pos"] += ball["vel"] * step_delta
			_handle_wall_collision(ball)
			if ball["pos"].y - ball["radius"] > PLAYFIELD.end.y + 24.0:
				lost = true
				_spawn_particles(ball["pos"], Color("ffd15f"), 12, 220.0, 0.55, 3.5)
				break
			_handle_paddle_collision(ball)
			if _handle_brick_collision(ball):
				break

		if lost:
			continue
		_normalize_ball_speed(ball)
		_push_ball_trail(ball)
		survivors.append(ball)

	balls = survivors
	if balls.is_empty() and state == "playing":
		lives -= 1
		if lives <= 0:
			state = "game_over"
			state_timer = 0.0
			menu_context = "game_over"
			_save_progress()
			_play_sfx("game_over")
		else:
			state = "serve"
			state_timer = 0.0
			balls.append(_make_ball(Vector2(paddle["pos"].x, paddle["pos"].y - 24.0), Vector2.ZERO, true))
			banner_text = "Ball lost"
			banner_timer = 1.2
			_play_sfx("pause")


func _handle_wall_collision(ball: Dictionary) -> void:
	if ball["pos"].x - ball["radius"] <= PLAYFIELD.position.x:
		ball["pos"].x = PLAYFIELD.position.x + ball["radius"] + 1.0
		ball["vel"].x = abs(ball["vel"].x)
		_spawn_particles(ball["pos"], Color("6fe7ff"), 3, 110.0, 0.18, 2.5)
	elif ball["pos"].x + ball["radius"] >= PLAYFIELD.end.x:
		ball["pos"].x = PLAYFIELD.end.x - ball["radius"] - 1.0
		ball["vel"].x = -abs(ball["vel"].x)
		_spawn_particles(ball["pos"], Color("6fe7ff"), 3, 110.0, 0.18, 2.5)

	if ball["pos"].y - ball["radius"] <= PLAYFIELD.position.y:
		ball["pos"].y = PLAYFIELD.position.y + ball["radius"] + 1.0
		ball["vel"].y = abs(ball["vel"].y)
		_spawn_particles(ball["pos"], Color("fff2b2"), 4, 120.0, 0.2, 2.7)


func _handle_paddle_collision(ball: Dictionary) -> void:
	var rect = Rect2(
		Vector2(paddle["pos"].x - paddle["width"] * 0.5, paddle["pos"].y - paddle["height"] * 0.5),
		Vector2(paddle["width"], paddle["height"])
	)
	var closest = Vector2(
		clampf(ball["pos"].x, rect.position.x, rect.end.x),
		clampf(ball["pos"].y, rect.position.y, rect.end.y)
	)
	if ball["vel"].y <= 0.0:
		return
	if ball["pos"].distance_squared_to(closest) > ball["radius"] * ball["radius"]:
		return

	var normalized_hit = clamp((ball["pos"].x - paddle["pos"].x) / max(paddle["width"] * 0.5, 1.0), -1.0, 1.0)
	var speed = max(ball["vel"].length(), 480.0)
	var direction = Vector2(normalized_hit * 0.92 + paddle["vx"] * 0.0007, -1.15).normalized()
	ball["vel"] = direction * speed
	ball["pos"].y = rect.position.y - ball["radius"] - 2.0
	_spawn_particles(ball["pos"], Color("ffe07a"), 10, 240.0, 0.35, 3.0)
	_shake(4.0)
	_play_sfx("paddle", randf_range(0.96, 1.08))
	if active_effects.has("catch"):
		ball["stuck"] = true
		ball["vel"] = Vector2.ZERO


func _handle_brick_collision(ball: Dictionary) -> bool:
	for brick in bricks:
		if not brick["alive"]:
			continue
		var rect: Rect2 = brick["rect"]
		var closest = Vector2(
			clampf(ball["pos"].x, rect.position.x, rect.end.x),
			clampf(ball["pos"].y, rect.position.y, rect.end.y)
		)
		var delta = ball["pos"] - closest
		if delta.length_squared() > ball["radius"] * ball["radius"]:
			continue

		var normal = Vector2.ZERO
		if delta.length_squared() > 0.001:
			normal = delta.normalized()
		else:
			var from_center = ball["pos"] - rect.get_center()
			if abs(from_center.x) > abs(from_center.y):
				normal = Vector2(sign(from_center.x), 0.0)
			else:
				normal = Vector2(0.0, sign(from_center.y))
		if normal == Vector2.ZERO:
			normal = Vector2.UP
		ball["vel"] = ball["vel"].bounce(normal)
		ball["pos"] = closest + normal * (ball["radius"] + 1.5)
		_damage_brick(brick, rect.get_center(), false)
		return true
	return false


func _damage_brick(brick: Dictionary, hit_point: Vector2, from_nova: bool) -> void:
	if not brick["alive"]:
		return

	brick["hits_left"] -= 1
	combo_clock = 2.0
	combo_multiplier = min(combo_multiplier + 1, 8)
	score += 25 * combo_multiplier
	if brick["hits_left"] > 0:
		_spawn_particles(hit_point, brick["highlight"], 14, 220.0, 0.38, 3.5)
		_float_score(hit_point, "CRACK", brick["highlight"])
		_shake(2.5)
		_play_sfx("brick_hit", rng.randf_range(0.94, 1.06))
		return

	brick["alive"] = false
	var points = brick["points"] * combo_multiplier
	score += points
	if score > high_score:
		high_score = score
	_spawn_particles(hit_point, brick["color"], 40, 360.0, 0.78, 6.4)
	_spawn_particles(hit_point, Color.WHITE, 16, 220.0, 0.5, 3.8)
	_float_score(hit_point, "+%d" % points, brick["highlight"])
	_flash(brick["glow"], 0.24)
	_shake(11.0 if brick.get("explosive", false) else 7.5)
	_play_sfx("explosion" if brick.get("explosive", false) else "brick_break", rng.randf_range(0.92, 1.08))

	if brick.get("explosive", false) and not from_nova:
		for neighbor in bricks:
			if not neighbor["alive"] or neighbor == brick:
				continue
			if neighbor["rect"].get_center().distance_to(hit_point) <= 110.0:
				_damage_brick(neighbor, neighbor["rect"].get_center(), true)

	if rng.randf() < 0.27:
		_spawn_powerup(hit_point)

	if _remaining_brick_count() == 0 and state != "level_clear":
		state = "level_clear"
		state_timer = 0.0
		banner_text = "Board cleared"
		banner_timer = 2.2


func _remaining_brick_count() -> int:
	var total = 0
	for brick in bricks:
		if brick["alive"]:
			total += 1
	return total


func _update_powerups(delta: float) -> void:
	var survivors: Array = []
	for pickup in powerups:
		pickup["pos"] += pickup["vel"] * delta
		pickup["wobble"] += delta * 5.0
		if pickup["pos"].y > PLAYFIELD.end.y + 44.0:
			continue
		var paddle_rect = Rect2(
			Vector2(paddle["pos"].x - paddle["width"] * 0.5, paddle["pos"].y - paddle["height"] * 0.5),
			Vector2(paddle["width"], paddle["height"])
		)
		var pickup_rect = Rect2(pickup["pos"] - Vector2(22, 12), Vector2(44, 24))
		if paddle_rect.intersects(pickup_rect):
			_collect_powerup(pickup)
			continue
		survivors.append(pickup)
	powerups = survivors


func _spawn_powerup(position: Vector2) -> void:
	var roll = rng.randf() * _total_powerup_weight()
	var selected = "wide"
	for key in POWERUP_META.keys():
		roll -= POWERUP_META[key]["weight"]
		if roll <= 0.0:
			selected = key
			break
	if settings["cheat"] and selected == "bomb":
		selected = "heart"

	var meta: Dictionary = POWERUP_META[selected]
	powerups.append(
		{
			"type": selected,
			"label": meta["label"],
			"title": meta["title"],
			"color": meta["color"],
			"bad": meta.get("bad", false),
			"pos": position,
			"vel": Vector2(rng.randf_range(-18.0, 18.0), 180.0),
			"wobble": rng.randf_range(0.0, TAU)
		}
	)


func _total_powerup_weight() -> float:
	var total = 0.0
	for key in POWERUP_META.keys():
		total += POWERUP_META[key]["weight"]
	return total


func _collect_powerup(pickup: Dictionary) -> void:
	var kind: String = pickup["type"]
	var meta: Dictionary = POWERUP_META[kind]
	_spawn_particles(pickup["pos"], pickup["color"], 22, 260.0, 0.55, 4.2)
	_float_score(pickup["pos"], meta["title"], pickup["color"])
	_flash(pickup["color"], 0.24)
	_shake(7.0 if meta.get("bad", false) else 5.0)
	_play_sfx("pickup_bad" if meta.get("bad", false) else "pickup_good", rng.randf_range(0.95, 1.08))

	match kind:
		"wide", "laser", "catch", "slow", "bomb":
			active_effects[kind] = meta["duration"]
			if kind == "slow":
				for ball in balls:
					if not ball["stuck"]:
						ball["vel"] *= 0.8
		"multi":
			_split_balls()
		"heart":
			if lives < _max_lives():
				lives = min(lives + 1, _max_lives())
			else:
				_split_balls()
		"nova":
			_trigger_nova()


func _split_balls() -> void:
	var spawned: Array = []
	for ball in balls:
		if ball["stuck"]:
			continue
		if balls.size() + spawned.size() >= 7:
			break
		for offset in [-0.42, 0.42]:
			var duplicate = _make_ball(ball["pos"], ball["vel"].rotated(offset), false)
			duplicate["trail"] = []
			spawned.append(duplicate)
	balls.append_array(spawned)
	if spawned.is_empty() and balls.size() == 1:
		var launched = _make_ball(balls[0]["pos"], Vector2(250.0, -520.0), false)
		launched["trail"] = []
		balls.append(launched)


func _trigger_nova() -> void:
	_flash(Color("ffb347", 0.88), 0.45)
	_shake(12.0)
	_play_sfx("explosion", 0.88)
	var hits = 0
	for brick in bricks:
		if not brick["alive"]:
			continue
		_damage_brick(brick, brick["rect"].get_center(), true)
		hits += 1
		if hits >= 12:
			break


func _update_effects(delta: float) -> void:
	var expired: Array = []
	for key in active_effects.keys():
		active_effects[key] -= delta
		if active_effects[key] <= 0.0:
			expired.append(key)
	for key in expired:
		active_effects.erase(key)
	if laser_cooldown > 0.0:
		laser_cooldown -= delta


func _update_lasers(delta: float) -> void:
	var survivors: Array = []
	for laser in lasers:
		laser["pos"] += laser["vel"] * delta
		laser["life"] -= delta
		if laser["pos"].y < PLAYFIELD.position.y or laser["life"] <= 0.0:
			continue
		var hit = false
		for brick in bricks:
			if not brick["alive"]:
				continue
			if brick["rect"].has_point(laser["pos"]):
				_damage_brick(brick, laser["pos"], false)
				hit = true
				break
		if not hit:
			survivors.append(laser)
	lasers = survivors


func _update_particles(delta: float) -> void:
	var survivors: Array = []
	for particle in particles:
		particle["life"] -= delta
		if particle["life"] <= 0.0:
			continue
		particle["pos"] += particle["vel"] * delta
		particle["vel"] *= 1.0 - min(delta * 2.5, 0.9)
		survivors.append(particle)
	particles = survivors


func _update_floaters(delta: float) -> void:
	var survivors: Array = []
	for floater in floaters:
		floater["life"] -= delta
		if floater["life"] <= 0.0:
			continue
		floater["pos"] += Vector2(0.0, -48.0) * delta
		survivors.append(floater)
	floaters = survivors


func _push_ball_trail(ball: Dictionary) -> void:
	ball["trail"].append(ball["pos"])
	while ball["trail"].size() > 8:
		ball["trail"].pop_front()


func _normalize_ball_speed(ball: Dictionary) -> void:
	var speed = ball["vel"].length()
	if speed < 1.0:
		ball["vel"] = Vector2(240.0, -520.0)
		speed = ball["vel"].length()
	var min_speed = 380.0 if active_effects.has("slow") else 460.0
	var max_speed = 560.0 if active_effects.has("slow") else 840.0
	speed = clamp(speed, min_speed, max_speed)
	ball["vel"] = ball["vel"].normalized() * speed


func _spawn_particles(position: Vector2, color: Color, amount: int, speed: float, life: float, radius: float) -> void:
	for _index in range(amount):
		var direction = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		var burst = speed * rng.randf_range(0.25, 1.0)
		particles.append(
			{
				"pos": position,
				"vel": direction * burst,
				"life": life * rng.randf_range(0.65, 1.15),
				"max_life": life,
				"color": color,
				"radius": radius * rng.randf_range(0.55, 1.1)
			}
		)


func _float_score(position: Vector2, text: String, color: Color) -> void:
	floaters.append(
		{
			"pos": position,
			"text": text,
			"life": 0.95,
			"max_life": 0.95,
			"color": color
		}
	)


func _flash(color: Color, amount: float) -> void:
	flash_color = color
	screen_flash = max(screen_flash, amount)


func _shake(amount: float) -> void:
	screen_shake = max(screen_shake, amount)


func _refresh_ui() -> void:
	score_label.text = "Score  %09d    Hi  %09d" % [score, high_score]
	level_label.text = current_level_name
	lives_label.text = "Balls  %d" % lives

	if combo_multiplier > 1:
		combo_label.visible = true
		combo_label.text = "Combo x%d" % combo_multiplier
	else:
		combo_label.visible = false

	var active_titles: Array = []
	for key in active_effects.keys():
		var meta: Dictionary = POWERUP_META.get(key, {})
		active_titles.append("%s %.0fs" % [meta.get("title", key), ceil(active_effects[key])])
	powers_label.text = "" if active_titles.is_empty() else "Active: %s" % " | ".join(active_titles)
	banner_label.visible = banner_timer > 0.0
	banner_label.text = banner_text

	title_label.visible = state in ["title", "game_over"]
	subtitle_label.visible = state in ["title", "game_over"]
	title_label.text = overlay_message
	subtitle_label.text = overlay_subtitle
	title_label.modulate.a = 0.0 if menu_panel.visible else 1.0
	subtitle_label.modulate.a = 0.0 if menu_panel.visible else 1.0


func _update_overlay() -> void:
	if state == "title":
		overlay_message = "CANDY BREAKOUT BOMBAST"
		overlay_subtitle = "DX-Ball-style brick chaos in a candy-store meltdown.\nMouse stays live. A and D are the preferred keyboard move keys. W or Space launches. F fires lasers."
	elif state == "game_over":
		if run_won:
			overlay_message = "SET COMPLETE"
			overlay_subtitle = "You emptied the candy store.\nClick or press Space to start another run."
		else:
			overlay_message = "GAME OVER"
			overlay_subtitle = "Best score is saved locally.\nClick or press Space to go again."
	else:
		overlay_message = ""
		overlay_subtitle = ""


func _draw() -> void:
	var level: Dictionary = LEVELS[level_index]
	var bg: Array = level["background"]

	draw_rect(Rect2(Vector2.ZERO, size), bg[0], true)
	for index in range(14):
		var t = float(index) / 13.0
		var y = lerp(0.0, size.y, t)
		var band_color = bg[0].lerp(bg[1], t).lerp(bg[2], 0.25)
		band_color.a = 0.85
		draw_rect(Rect2(Vector2(0.0, y), Vector2(size.x, size.y / 13.0 + 2.0)), band_color, true)

	for blob in range(7):
		var wobble = title_phase * (0.15 + blob * 0.03)
		var center = Vector2(
			200.0 + blob * 210.0 + sin(wobble * 1.6 + blob) * 80.0,
			140.0 + fmod(blob * 110.0 + title_phase * 16.0, size.y + 220.0)
		)
		var radius = 90.0 + 40.0 * sin(wobble + blob)
		var glow = bg[2].lerp(bg[1], float(blob % 3) / 2.0)
		glow.a = 0.12
		draw_circle(center + camera_offset * 0.15, radius, glow)

	for stripe in range(20):
		var offset = fmod(title_phase * 120.0 + stripe * 88.0, size.x + 300.0) - 150.0
		var stripe_color: Color = level["stripe"]
		draw_line(
			Vector2(offset, PLAYFIELD.position.y - 110.0) + camera_offset * 0.1,
			Vector2(offset + 220.0, PLAYFIELD.end.y + 140.0) + camera_offset * 0.1,
			stripe_color,
			3.0
		)

	var field = PLAYFIELD
	var outer_field = Rect2(field.grow(16.0).position + camera_offset * 0.35, field.grow(16.0).size)
	var inner_field = Rect2(field.position + camera_offset * 0.2, field.size)
	draw_rect(outer_field, Color("2ce8ff", 0.08), true)
	draw_rect(inner_field, Color("0b1027", 0.86), true)
	draw_rect(inner_field, Color("7fdfff", 0.42), false, 3.0)

	_draw_bricks()
	_draw_powerups()
	_draw_lasers()
	_draw_paddle()
	_draw_balls()
	_draw_particles()
	_draw_floaters()

	if screen_flash > 0.0:
		var overlay = flash_color
		overlay.a = min(screen_flash, 0.45)
		draw_rect(Rect2(Vector2.ZERO, size), overlay, true)


func _draw_bricks() -> void:
	for brick in bricks:
		if not brick["alive"]:
			continue
		var source_rect: Rect2 = brick["rect"]
		var rect = Rect2(source_rect.position + camera_offset * 0.35, source_rect.size)
		draw_rect(rect.grow(6.0), Color(brick["glow"], 0.11), true)
		draw_rect(rect, brick["color"], true)
		draw_rect(Rect2(rect.position + Vector2(0, 2), Vector2(rect.size.x, rect.size.y * 0.32)), brick["highlight"], true)
		draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), Color(brick["color"]).darkened(0.18), false, 2.0)
		if brick["hits_left"] < brick["max_hits"]:
			var crack_color = Color.WHITE
			crack_color.a = 0.65
			draw_line(rect.position + Vector2(10, 10), rect.end - Vector2(12, 14), crack_color, 2.0)
			draw_line(rect.position + Vector2(rect.size.x * 0.55, 8), rect.position + Vector2(rect.size.x * 0.35, rect.size.y - 8), crack_color, 2.0)
		if brick.get("explosive", false):
			draw_line(rect.position + Vector2(12, rect.size.y * 0.5), rect.end - Vector2(12, rect.size.y * 0.5), Color.WHITE, 2.0)
			draw_line(rect.position + Vector2(rect.size.x * 0.5, 8), rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 8), Color.WHITE, 2.0)


func _draw_paddle() -> void:
	var rect = Rect2(
		Vector2(paddle["pos"].x - paddle["width"] * 0.5, paddle["pos"].y - paddle["height"] * 0.5) + camera_offset,
		Vector2(paddle["width"], paddle["height"])
	)
	var shell_color = Color("8a5cff") if active_effects.has("bomb") else Color("ff8a23")
	var glow_color = Color("ff5bcb", 0.18) if active_effects.has("bomb") else Color("ffe66c", 0.13)
	draw_rect(rect.grow(12.0), glow_color, true)
	draw_rect(rect, shell_color, true)
	draw_rect(Rect2(rect.position + Vector2(0, 2), Vector2(rect.size.x, rect.size.y * 0.38)), Color("fff7bc"), true)
	draw_rect(Rect2(rect.position + Vector2(6, 5), rect.size - Vector2(12, 10)), Color("ff4eb4"), false, 2.0)
	draw_rect(Rect2(rect.position, Vector2(22, rect.size.y)), Color("27d8ff"), true)
	draw_rect(Rect2(rect.end - Vector2(22, rect.size.y), Vector2(22, rect.size.y)), Color("27d8ff"), true)
	if active_effects.has("laser"):
		draw_rect(Rect2(rect.position + Vector2(4, -14), Vector2(12, 14)), Color("fffb9a"), true)
		draw_rect(Rect2(rect.end + Vector2(-16, -14), Vector2(12, 14)), Color("fffb9a"), true)


func _draw_balls() -> void:
	for ball in balls:
		var trail: Array = ball["trail"]
		for index in range(trail.size()):
			var alpha = float(index + 1) / float(max(trail.size(), 1))
			var trail_color = Color(ball["tint"])
			trail_color.a = alpha * 0.28
			draw_circle(trail[index] + camera_offset * 0.45, ball["radius"] * alpha, trail_color)
		draw_circle(ball["pos"] + camera_offset, ball["radius"] + 7.0, Color("ffffff", 0.12))
		draw_circle(ball["pos"] + camera_offset, ball["radius"], Color("ffffff"))
		draw_circle(ball["pos"] + camera_offset + Vector2(-3, -3), 3.0, Color("fff7c1"))


func _draw_powerups() -> void:
	for pickup in powerups:
		var body_rect = Rect2(
			pickup["pos"] + camera_offset * 0.4 + Vector2(0, sin(pickup["wobble"]) * 4.0) - Vector2(22, 12),
			Vector2(44, 24)
		)
		draw_rect(body_rect.grow(10.0), Color(pickup["color"], 0.14), true)
		draw_rect(body_rect, pickup["color"], true)
		draw_rect(Rect2(body_rect.position + Vector2(0, 2), Vector2(body_rect.size.x, 8)), Color.WHITE, true)
		draw_string(
			ThemeDB.fallback_font,
			body_rect.position + Vector2(13, 19),
			pickup["label"],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			18,
			Color("3b0823") if pickup["bad"] else Color("201339")
		)


func _draw_lasers() -> void:
	for laser in lasers:
		draw_line(laser["pos"] + camera_offset, laser["pos"] + camera_offset + Vector2(0, 32), Color("fff69a"), 4.0)
		draw_line(laser["pos"] + camera_offset, laser["pos"] + camera_offset + Vector2(0, 32), Color("ff7f1f", 0.5), 8.0)


func _draw_particles() -> void:
	for particle in particles:
		var alpha = particle["life"] / particle["max_life"]
		var color: Color = particle["color"]
		color.a *= alpha
		draw_circle(particle["pos"] + camera_offset * 0.5, particle["radius"] * alpha, color)


func _draw_floaters() -> void:
	for floater in floaters:
		var alpha = floater["life"] / floater["max_life"]
		var color: Color = floater["color"]
		color.a = alpha
		draw_string(
			ThemeDB.fallback_font,
			floater["pos"] + camera_offset * 0.15,
			floater["text"],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			24,
			color
		)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state in ["serve", "playing", "paused"]:
			_toggle_pause()
		elif options_open:
			_close_options()
	elif settings["cheat"] and event.is_action_pressed("cheat_skip"):
		if state in ["serve", "playing"]:
			banner_text = "Cheat skip"
			banner_timer = 1.0
			_play_sfx("level_clear")
			if level_index < LEVELS.size() - 1:
				_load_level(level_index + 1)
			else:
				run_won = true
				state = "game_over"
				menu_context = "game_over"
				_refresh_menu_ui()
	elif settings["cheat"] and event.is_action_pressed("cheat_ball"):
		if state in ["serve", "playing"] and balls.size() < 8:
			var bonus_ball = _make_ball(Vector2(paddle["pos"].x, paddle["pos"].y - 36.0), Vector2(rng.randf_range(-220.0, 220.0), -540.0), false)
			balls.append(bonus_ball)
			_play_sfx("pickup_good")
	elif event.is_action_pressed("launch"):
		_handle_primary_action()
	elif event.is_action_pressed("shoot"):
		_try_fire_lasers()


func _handle_primary_action() -> void:
	if state == "title":
		_start_new_game()
		state = "serve"
		state_timer = 0.0
		menu_context = ""
		options_open = false
		_play_sfx("launch")
	elif state == "game_over":
		_start_new_game()
		state = "serve"
		state_timer = 0.0
		menu_context = ""
		options_open = false
		_play_sfx("launch")
	elif state in ["serve", "playing"]:
		if _has_stuck_ball():
			_launch_stuck_balls()
		elif active_effects.has("laser"):
			_try_fire_lasers()
	_refresh_menu_ui()


func _has_stuck_ball() -> bool:
	for ball in balls:
		if ball["stuck"]:
			return true
	return false


func _launch_stuck_balls() -> void:
	state = "playing"
	for ball in balls:
		if not ball["stuck"]:
			continue
		var spread = rng.randf_range(-0.38, 0.38)
		ball["stuck"] = false
		ball["vel"] = Vector2(spread * 260.0, -560.0)
	_play_sfx("launch", rng.randf_range(0.98, 1.04))


func _try_fire_lasers() -> void:
	if not active_effects.has("laser") or laser_cooldown > 0.0:
		return
	if state not in ["serve", "playing"]:
		return
	state = "playing"
	laser_cooldown = 0.24
	var y = paddle["pos"].y - 18.0
	lasers.append({"pos": Vector2(paddle["pos"].x - paddle["width"] * 0.36, y), "vel": Vector2(0, -980), "life": 0.8})
	lasers.append({"pos": Vector2(paddle["pos"].x + paddle["width"] * 0.36, y), "vel": Vector2(0, -980), "life": 0.8})
	_spawn_particles(Vector2(paddle["pos"].x, y), Color("ffe879"), 10, 180.0, 0.25, 3.5)
	_play_sfx("laser", rng.randf_range(0.98, 1.03))


func _load_progress() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		high_score = 0
		return
	high_score = int(config.get_value("scores", "high_score", 0))
	settings["speed"] = int(config.get_value("settings", "speed", settings["speed"]))
	settings["cheat"] = bool(config.get_value("settings", "cheat", settings["cheat"]))
	settings["music"] = bool(config.get_value("settings", "music", settings["music"]))
	settings["sfx"] = bool(config.get_value("settings", "sfx", settings["sfx"]))
	settings["volume"] = float(config.get_value("settings", "volume", settings["volume"]))


func _save_progress() -> void:
	high_score = max(high_score, score)
	var config = ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.set_value("settings", "speed", settings["speed"])
	config.set_value("settings", "cheat", settings["cheat"])
	config.set_value("settings", "music", settings["music"])
	config.set_value("settings", "sfx", settings["sfx"])
	config.set_value("settings", "volume", settings["volume"])
	config.save(SAVE_PATH)
