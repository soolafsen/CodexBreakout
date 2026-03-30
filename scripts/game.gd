extends Control

const AudioSynth = preload("res://scripts/audio_synth.gd")
const PLAYFIELD = Rect2(Vector2(120.0, 150.0), Vector2(1360.0, 660.0))
const BASE_PADDLE_WIDTH = 170.0
const PADDLE_HEIGHT = 24.0
const BALL_RADIUS = 10.0
const SAVE_PATH = "user://progress.cfg"
const TARGET_LEVEL_COUNT = 99
const GAME_SPEED_LEVELS = [0.32, 0.4, 0.5, 0.61, 0.73, 0.86, 1.0, 1.15, 1.31, 1.48]

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
	"bomb": {"label": "B", "title": "Bomb Slow", "color": Color("ff4c86"), "weight": 10.0, "duration": 10.0, "bad": true}
}

var levels: Array = []

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
var current_level = {}
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
var brick_wall_offset = 0.0
var brick_wall_upper_offset = 0.0
var brick_wall_lower_offset = 0.0
var brick_wall_direction = 1.0
var settings = {
	"speed": 5,
	"key_sensitivity": 30,
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
var key_sensitivity_value_label: Label
var key_sensitivity_slider: HSlider
var cheat_toggle: CheckButton
var music_toggle: CheckButton
var sfx_toggle: CheckButton
var volume_value_label: Label
var volume_slider: HSlider


func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_input_actions()
	levels = _build_level_library()
	if levels.size() != TARGET_LEVEL_COUNT:
		push_warning("Expected %d levels, built %d." % [TARGET_LEVEL_COUNT, levels.size()])
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


func _build_level_library() -> Array:
	var candy_palettes = [
		{"bg": [Color("16052e"), Color("3b1174"), Color("0bb6ff")], "stripe": Color("ff57c8", 0.18)},
		{"bg": [Color("081633"), Color("1d4bcf"), Color("ff4fbe")], "stripe": Color("8dfff3", 0.18)},
		{"bg": [Color("17062a"), Color("5a157e"), Color("ffbf47")], "stripe": Color("68f7ff", 0.16)},
		{"bg": [Color("102041"), Color("145f88"), Color("8cff72")], "stripe": Color("ffd36c", 0.16)},
		{"bg": [Color("1a0430"), Color("6a117e"), Color("ffd34d")], "stripe": Color("42f5ff", 0.16)}
	]
	var sinister_palettes = [
		{"bg": [Color("040506"), Color("141516"), Color("3e2320")], "stripe": Color("5c4a48", 0.14)},
		{"bg": [Color("040507"), Color("101318"), Color("28323a")], "stripe": Color("52606a", 0.13)},
		{"bg": [Color("060506"), Color("181214"), Color("3a2429")], "stripe": Color("615055", 0.14)},
		{"bg": [Color("050505"), Color("141414"), Color("2a2421")], "stripe": Color("5b4c45", 0.13)}
	]

	var base_levels = [
		_make_level("Candy Crown", "Open the vault", [
			".......AABCCBBAA.......",
			"......AABCDDDDCBAA......",
			".....AABCDESSSEDCBA.....",
			"....AABCDESXXSEDCBA....",
			"...AABCDDDESSSEDDCBA...",
			"..AABCCDDEEEEEEDDCCBA..",
			".AABCCDDEEDDDDEEDDCCBA.",
			".AABCCDDEEDDDDEEDDCCBA.",
			"..AABCDDEEEEEEEEDDCBA..",
			"...AABBCCDDEEDDCCBBA...",
			".....AABBCCDDCCBBA.....",
			"........AABBCCAA........"
		], candy_palettes[0]),
		_make_level("Prism Pulse", "Surf the sugar storm", [
			"AA..BB..CC..DD..EE..AA",
			".AA..BB..CC..DD..EE..A",
			"..AA..BB..CC..DD..EE..",
			"...AA..BB..CC..DD..E..",
			"SSSAAABBXXCCCDDDEESSSS",
			"...EE..DD..CC..BB..A..",
			"..EE..DD..CC..BB..AA..",
			".EE..DD..CC..BB..AA...",
			"AA..BB..CC..DD..EE..AA",
			".AA..BB..CC..DD..EE..A",
			"..SS..EE..XX..DD..SS..",
			"....AA..BB..CC..DD...."
		], candy_palettes[1]),
		_make_level("Bunny Bounce", "Long ears, fast sugar", [
			".......AA......AA.......",
			"......ABBA....ABBA......",
			"......ABBA....ABBA......",
			".......AA......AA.......",
			".....CCCDDXXDDCCCDD.....",
			"....CCDDEESSSSEEDDCC....",
			"...CCDDEEEEEEEEEEDDCC...",
			"...CCDDEEXXEEEXXEEDD...",
			"...CCDDEEEEEEEEEEDDCC...",
			"....CCDDEDDDDDDDEDD....",
			".....CCDDEECCEECCDD.....",
			".......CC......CC......."
		], candy_palettes[2]),
		_make_level("Egg Basket", "Spring loot drop", [
			"....AA....BB....CC....",
			"...AADD..BBEE..CCDD...",
			"..AADDEE.BBEEDD.CCDDEE..",
			"...AADD..BBEE..CCDD...",
			"........................",
			"..DDDDDDDDDDDDDDDDDD..",
			".DEEEEEEEEEEEEEEEEED.",
			".DEDDDDDDDDDDDDDDDDE.",
			".DEEEEEEEEEEEEEEEEED.",
			"..DDEEDD..DDEEDD..DD..",
			"...DD......DD......D...",
			"....D......DD......D..."
		], candy_palettes[3]),
		_make_level("Skull Eclipse", "Candy night falls", [
			".....AA..BBCCBB..AA.....",
			"...AABBCCDDDDDDCCBBAA...",
			"..AABBCCDDEEESSDDCCBBA..",
			".AABBCDDEEXXSSXXEEDDCCBA.",
			".AABBCDDEESSSSSSEEDDCCBA.",
			".AABBCCDDSSXXSSDDCCBBAA.",
			"..AABBCCDSSSSSSDDCCBBA..",
			"..AABBCCDDEESEEEDDCCBA..",
			"...AABBCCDDEEEDDCCBBA...",
			"....AABB..DDDD..BBAA....",
			".....AA....DD....AA.....",
			"......A....DD....A......"
		], sinister_palettes[0], true),
		_make_level("Chocolate Bar", "Break the wrapper", [
			".EEEE..EEEE..EEEE..EEEE.",
			".ECCD..ECCD..ECCD..ECCD.",
			".ECCD..ECCD..ECCD..ECCD.",
			".EEEE..EEEE..EEEE..EEEE.",
			"........................",
			".AABB..AABB..AABB..AABB.",
			".AABB..AABB..AABB..AABB.",
			".CCDD..CCDD..CCDD..CCDD.",
			".CCDD..CCDD..CCDD..CCDD.",
			".SSXX..SSXX..SSXX..SSXX.",
			".SSDD..SSDD..SSDD..SSDD.",
			".AABB..CCDD..EEAA..BBCC."
		], candy_palettes[4]),
		_make_level("Carrot Rocket", "Up through the clouds", [
			"...........AA...........",
			"..........ABBA..........",
			".........ABCCBA.........",
			"........ABCDDCBA........",
			".......ABCDXXDCBA.......",
			"......ABCDESSSDCBA......",
			".....ABCDESSSSEDCBA.....",
			".....BBCCDDEEEDDCCBB....",
			"......BBCCDDEEDDCCBB....",
			".......DD..DDDD..DD.....",
			"......DD....DD....DD....",
			".....CC....CCCC....CC..."
		], candy_palettes[0]),
		_make_level("Ribbon Wheels", "Spin the sweet ride", [
			"...AA..............AA...",
			"..ABBA............ABBA..",
			".ABCCBA..........ABCCBA.",
			".ABDDCBA..CCCC..ABDDCBA.",
			"..ABBA..CCDDDDCC..ABBA..",
			"...AA..CCDDEEDDCC..AA...",
			"......CCDDEXXEEDCC......",
			"..EE..CCDDEEEDDCC..EE..",
			".EEDD..CCDDDDDDCC..DDEE.",
			"..EE....CCCCCCCC....EE..",
			"...AA..............AA...",
			"..ABBA............ABBA.."
		], candy_palettes[1]),
		_make_level("Wrapped Eggs", "Crack the festival stash", [
			"....AA....BB....CC....",
			"...ABBA..BCCB..CDDC...",
			"..ABDDBA.BCDCB.CDEEDC..",
			"...ABBA..BCCB..CDDC...",
			"....AA....BB....CC....",
			"........................",
			"....DD....EE....SS....",
			"...DEED..ESSE..SDDS...",
			"..DEXXED.ESSSE.SDXXDS..",
			"...DEED..ESSE..SDDS...",
			"....DD....EE....SS....",
			"...AA....BB....CC......"
		], candy_palettes[2]),
		_make_level("Grave Bite", "The sugar turns feral", [
			"XX....SS....SS....XX",
			".XX..SSSS..SSSS..XX.",
			"..XX.SSXX..XXSS.XX..",
			"...XXSS......SSXX...",
			"....DDDDDDDDDDDD....",
			"...DDEEEEEEEEEEDD...",
			"..DDEEXXEEEEXXEEDD..",
			".DDEESSSSEESSSSEEDD.",
			".DDEESSSSEESSSSEEDD.",
			"..DDEE..DDDD..EEDD..",
			"...DD....DD....DD...",
			"....D....DD....D...."
		], sinister_palettes[1], true),
		_make_level("Pinwheel Pop", "Five flavors collide", [
			"........CC........",
			".......CCCC.......",
			"...AA...CC...BB...",
			"...AAA..CC..BBB...",
			"AAAAAAXXCCXXBBBBBB",
			"...AAA..SS..BBB...",
			"...AA...SS...BB...",
			".......SSSS.......",
			"........SS........",
			"...DD...EE...AA...",
			"..DDDD.EEEE.AAAA..",
			"...DD...EE...AA..."
		], candy_palettes[3]),
		_make_level("Bunny Face", "Smile and smash", [
			".......AA......AA.......",
			"......ABBA....ABBA......",
			"......ABBA....ABBA......",
			".......AA......AA.......",
			".....CCCDDCCCCDDCCC.....",
			"....CCDDEECCCCEEDDCC....",
			"...CCDDEEXX..XXEEDDCC...",
			"...CCDDEEEEEEEEEEDDCC...",
			"...CCDDE........EDDCC...",
			"....CCDDE......EDDCC....",
			".....CCDDDDDDDDDDCC.....",
			".......CC......CC......."
		], candy_palettes[4]),
		_make_level("Egg Parade", "March of the shells", [
			".AA....BB....CC....DD.",
			"ABBA..BCCB..CDDC..DEED",
			"ADDA..BDDB..CEEC..DDDD",
			"ABBA..BCCB..CDDC..DEED",
			".AA....BB....CC....DD.",
			"........................",
			".DD....EE....SS....AA.",
			"DDDD..ESSE..ASSA..BDDB",
			"DEED..ESSE..AEEA..BCCB",
			"DDDD..ESSE..ASSA..BDDB",
			".DD....EE....SS....AA.",
			"....CC....DD....EE...."
		], candy_palettes[0]),
		_make_level("Candy Cruiser", "Road trip through syrup", [
			"........................",
			"........................",
			"....AABB........CCDD....",
			"...AABBDD......CCDDEE...",
			"..AABBDDSSXXXXSSDDEECC..",
			".AABBDDEEEEEEEEEEDDCCB.",
			".AABBDDEEDDDDDEEDDCCB.",
			"..AA..DD......DD..CC...",
			".ABBA..D......D..BCCB..",
			"ABCCBA...........BDDCBA",
			".ABBA............BCCB..",
			"..AA..............CC..."
		], candy_palettes[1]),
		_make_level("I Wait", "The walls are listening", [
			"....XX....SS....XX....",
			"...XXXX..SSSS..XXXX...",
			"........................",
			".A.A.A...AAA..A...AAA.",
			".A.A.A...A.A..A....A..",
			".A.A.A...AAA..A....A..",
			".A.A.A...A.A..A....A..",
			"..A.A....A.A..A....A..",
			"........................",
			"..DD..DD..SSXX..DD..DD.",
			".DDEE..DDEE..DDEE..DD..",
			"..DD....DD....DD....DD."
		], sinister_palettes[2], true),
		_make_level("Chocolate Castle", "Walls of nougat", [
			"........EEEE........",
			".......ECCCCE.......",
			"......ECCDDECCE......",
			".....EECCDDEECCEE.....",
			"....EESSDDSSDDSSEE....",
			"...EEESSEESSDDEESSEE...",
			"..EEE..............EEE..",
			".EEDD..AABBXXBBAA..DDEE.",
			".EEDD..AABBDDBBAA..DDEE.",
			".EEDD..CCDDEEDDCC..DDEE.",
			"..EE....CC....CC....EE..",
			"...E....CC....CC....E..."
		], candy_palettes[2]),
		_make_level("Carrot Launcher", "Spring fireworks", [
			"...........AA...........",
			"..........ABBA..........",
			".........ABCCBA.........",
			"........ABCDDCBA........",
			".......ABCDXXDCBA.......",
			"......ABCDESSSDCBA......",
			".....ABCDESSSSEDCBA.....",
			"......BBCCDDDDCCBB......",
			".......BBCCDDECBB.......",
			"....AA....DDDD....AA....",
			"...ABBA...DDDD...ABBA...",
			"..ABCCBA..CCCC..ABCCBA.."
		], candy_palettes[3]),
		_make_level("Basket Weave", "Patchwork of sugar", [
			"AABB..CCDDEE..AABB..CC",
			"AABB..CCDDEE..AABB..CC",
			"..DDEE..AABBCC..DDEE..",
			"..DDEE..AABBCC..DDEE..",
			"SS..AABB..XX..CCDDEE..",
			"SS..AABB..XX..CCDDEE..",
			"..CCDDEE..AABB..SS..AA",
			"..CCDDEE..AABB..SS..AA",
			"EESS..CCDDEE..AABB..CC",
			"EESS..CCDDEE..AABB..CC",
			"..AABB..SSXX..DDEE..AA",
			"..AABB..SSXX..DDEE..AA"
		], candy_palettes[4]),
		_make_level("Be Kind", "Sugar is better shared", [
			"....AA....BB....CC....",
			"...ABBA..BCCB..CDDC...",
			"........................",
			"AAA.AAA..A.A.A.A.A.AAA",
			"A.A.A....AA..A.AA.A.A",
			"AAA.AAA..A...A.A.A.A.A",
			"A.A.A....AA..A.A.A.A.A",
			"AAA.AAA..A.A.A.A.A.AAA",
			"........................",
			"...DD....EE....SS.....",
			"..DDEE..EESS..SSDD....",
			"...DD....EE....SS....."
		], candy_palettes[0]),
		_make_level("Final Skull Storm", "The candy goes black", [
			"....XX....SS....XX....",
			"...XXXX..SSSS..XXXX...",
			"..XXEEXXSSXXSSXXEEXX..",
			".XXEEDDXXXXXXDDEEXX.",
			".XDEESSSSDDSSSSEEDX.",
			".DDEESSXXSSXXSSEEDD.",
			".DDEESSSSSSSSSSEEDD.",
			"..DDEEXXEEEEEXXEEDD..",
			"...DDEEEEEEEEEEDD...",
			"....DD..DDDD..DD....",
			".....D...DD...D.....",
			"......D..DD..D......"
		], sinister_palettes[3], true)
	]
	base_levels.append_array(_build_generated_levels(base_levels.size(), TARGET_LEVEL_COUNT, candy_palettes, sinister_palettes))
	return base_levels


func _make_level(name: String, tagline: String, layout: Array, palette: Dictionary, sinister: bool = false) -> Dictionary:
	return {
		"name": name,
		"tagline": tagline,
		"layout": layout,
		"background": palette["bg"],
		"stripe": palette["stripe"],
		"theme": "sinister" if sinister else "candy",
		"ball_speed_multiplier": 1.2 if sinister else 1.0,
		"brick_fall_speed": 10.0 if sinister else 4.0,
		"bomb_multiplier": 2.0 if sinister else 1.0,
		"allow_heart": not sinister
	}


func _build_generated_levels(start_index: int, target_count: int, candy_palettes: Array, sinister_palettes: Array) -> Array:
	var results: Array = []
	var candy_motifs = [
		"diamond", "wave", "rings", "bunny", "eggs", "basket", "carrot", "clown",
		"car", "bicycle", "heart", "crown", "castle", "pinwheel", "flower", "capsule",
		"ribbon", "rocket", "weave", "stairs"
	]
	var sinister_motifs = [
		"skull", "vault", "serpent", "hourglass", "spiral", "eclipse", "tomb", "tower", "sigil", "maw",
		"cage", "altar", "thorns", "cathedral", "graveyard", "idol", "claw", "furnace", "mask", "bones"
	]
	var candy_words = ["BE KIND", "LOVE CANDY", "HOP HOP", "SWEET DAY", "SOFT GLOW", "JOY POP"]
	var sinister_words = [
		"I WAIT", "I SEE", "NO EXIT", "WE WATCH", "ASH FALLS", "COLD SUGAR", "STAY STILL", "LOW LIGHT",
		"IT KNOWS", "LAST GLOW", "BLACK RAIN", "HUSH NOW", "NO MERCY", "DUST SPEAKS", "CANDY DIES",
		"DO NOT RUN", "THEY STARE", "NIGHT WINS", "ASH WATCH"
	]

	while start_index + results.size() < target_count:
		var level_number = start_index + results.size() + 1
		var sinister = level_number % 5 == 0
		var sinister_index = int(level_number / 5) - 1
		var palette_pool = sinister_palettes if sinister else candy_palettes
		var motif_pool = sinister_motifs if sinister else candy_motifs
		var word_pool = sinister_words if sinister else candy_words
		var palette = palette_pool[level_number % palette_pool.size()]
		var use_text = false
		if sinister:
			use_text = sinister_index >= motif_pool.size()
		else:
			use_text = level_number % 7 == 0 or level_number % 11 == 0
		var motif = word_pool[sinister_index % word_pool.size()] if use_text and sinister else (word_pool[level_number % word_pool.size()] if use_text else (motif_pool[sinister_index % motif_pool.size()] if sinister else motif_pool[level_number % motif_pool.size()]))
		var layout = _generate_phrase_layout(motif, sinister, level_number) if use_text else _generate_pattern_layout(motif, sinister, level_number)
		var name = _generated_level_name(level_number, motif, sinister, use_text)
		var tagline = _generated_level_tagline(level_number, motif, sinister, use_text)
		results.append(_make_level(name, tagline, layout, palette, sinister))

	return results


func _generated_level_name(level_number: int, motif: String, sinister: bool, use_text: bool) -> String:
	var candy_prefixes = [
		"Jelly", "Sparkle", "Bonbon", "Fizzy", "Marshmallow", "Lemon", "Bubble", "Toffee", "Caramel", "Confetti",
		"Neon", "Bunny", "Sprinkle", "Ribbon", "Lollipop", "Velvet", "Sunny", "Sugar", "Glitter", "Candy"
	]
	var sinister_prefixes = [
		"Ashen", "Hollow", "Worn", "Blackglass", "Rust", "Silent", "Bleak", "Cold", "Dread", "Ember",
		"Grave", "Sunless", "Static", "Cinder", "Broken", "Last", "Null", "Feral", "Spent"
	]
	var prefix_pool = sinister_prefixes if sinister else candy_prefixes
	var prefix = prefix_pool[((level_number / 5) if sinister else level_number) % prefix_pool.size()]
	if use_text:
		return "%s Message %02d" % [prefix, level_number]
	return "%s %s %02d" % [prefix, _motif_title(motif), level_number]


func _generated_level_tagline(level_number: int, motif: String, sinister: bool, use_text: bool) -> String:
	var candy_openers = [
		"Keep the rainbow bouncing", "Spring sugar in motion", "Too bright to fail", "Crash through the jelly sky",
		"A carnival made of frosting", "The aisle goes neon", "Pocket-sized easter chaos", "Candy rain over chrome",
		"Soft colors, hard rebounds", "Push deeper into the sweets", "Turn the sugar storm louder", "Every color wants to pop",
		"More glow, less mercy", "Bounce through the sugar rush", "A chorus of wrappers and light", "Glitter under pressure"
	]
	var sinister_openers = [
		"The candy store is rotting", "Ash falls where glitter was", "The aisle remembers you", "Only the bounce stays bright",
		"Everything sweet has gone stale", "The sugar fights back", "An arcade after the sirens", "Under the glaze, only ruin",
		"The wrappers whisper again", "The shelf light has died", "Dust gathers under the syrup", "The room keeps watching"
	]
	var candy_closers = [
		"with %s in the walls", "under a sugar-storm sky", "through the sparkle machine", "before the frosting cools",
		"with all colors turned loud", "while the wrappers sing", "under the candyland grid", "before the syrup settles"
	]
	var sinister_closers = [
		"around the %s", "under the dead fluorescents", "while the glaze flakes away", "inside the ruined aisle",
		"where the arcade forgot its lights", "with ash in every rebound", "after the sugar went bad", "under the stale neon"
	]
	var opener_pool = sinister_openers if sinister else candy_openers
	var closer_pool = sinister_closers if sinister else candy_closers
	var opener = opener_pool[(level_number * 3 + motif.length()) % opener_pool.size()]
	var closer = closer_pool[(level_number * 5 + motif.length()) % closer_pool.size()]
	if use_text:
		return opener
	return "%s %s" % [opener, closer % _motif_tagline_label(motif)]


func _motif_title(motif: String) -> String:
	match motif:
		"diamond":
			return "Diamond"
		"wave":
			return "Current"
		"rings":
			return "Orbit"
		"bunny":
			return "Bunny"
		"eggs":
			return "Egg Bloom"
		"basket":
			return "Basket"
		"carrot":
			return "Carrot"
		"clown":
			return "Parade"
		"car":
			return "Cruiser"
		"bicycle":
			return "Spokes"
		"heart":
			return "Heart"
		"crown":
			return "Crown"
		"castle":
			return "Castle"
		"pinwheel":
			return "Pinwheel"
		"flower":
			return "Bloom"
		"capsule":
			return "Capsule"
		"ribbon":
			return "Ribbon"
		"rocket":
			return "Rocket"
		"weave":
			return "Weave"
		"stairs":
			return "Stairs"
		"skull":
			return "Skull"
		"vault":
			return "Vault"
		"serpent":
			return "Serpent"
		"hourglass":
			return "Hourglass"
		"spiral":
			return "Spiral"
		"eclipse":
			return "Eclipse"
		"tomb":
			return "Tomb"
		"tower":
			return "Tower"
		"cage":
			return "Cage"
		"altar":
			return "Altar"
		"thorns":
			return "Thorns"
		"cathedral":
			return "Cathedral"
		"graveyard":
			return "Graveyard"
		"idol":
			return "Idol"
		"claw":
			return "Claw"
		"furnace":
			return "Furnace"
		"mask":
			return "Mask"
		"bones":
			return "Bones"
		"sigil":
			return "Sigil"
		"maw":
			return "Maw"
		_:
			return motif.capitalize()


func _motif_tagline_label(motif: String) -> String:
	match motif:
		"diamond":
			return "cut glass"
		"wave":
			return "tidal light"
		"rings":
			return "orbiting sugar"
		"bunny":
			return "rabbit tracks"
		"eggs":
			return "painted shells"
		"basket":
			return "woven sugar"
		"carrot":
			return "spring roots"
		"clown":
			return "painted grins"
		"car":
			return "chrome candy"
		"bicycle":
			return "spinning spokes"
		"heart":
			return "soft hearts"
		"crown":
			return "candied royalty"
		"castle":
			return "frosted walls"
		"pinwheel":
			return "turning wrappers"
		"flower":
			return "sugar petals"
		"capsule":
			return "glow shells"
		"ribbon":
			return "ribbon trails"
		"rocket":
			return "sweet exhaust"
		"weave":
			return "stitched candy"
		"stairs":
			return "stacked steps"
		"skull":
			return "empty teeth"
		"vault":
			return "sealed doors"
		"serpent":
			return "coiled sugar"
		"hourglass":
			return "falling time"
		"spiral":
			return "deep loops"
		"eclipse":
			return "dead sun"
		"tomb":
			return "sealed stone"
		"tower":
			return "dark watch"
		"cage":
			return "barred dark"
		"altar":
			return "silent stone"
		"thorns":
			return "hooked vines"
		"cathedral":
			return "dead arches"
		"graveyard":
			return "cold plots"
		"idol":
			return "empty worship"
		"claw":
			return "reaching dark"
		"furnace":
			return "burned air"
		"mask":
			return "borrowed faces"
		"bones":
			return "dry remains"
		"sigil":
			return "burned marks"
		"maw":
			return "hungry dark"
		_:
			return motif.to_lower()


func _generate_pattern_layout(motif: String, sinister: bool, variant: int) -> Array:
	var width = 30
	var height = 14
	var grid = _make_grid(width, height)

	match motif:
		"diamond":
			for y in range(height):
				for x in range(width):
					var dx = abs(x - width * 0.5 + 0.5)
					var dy = abs(y - 5.8)
					if dx + dy * 1.8 < 9.8 or (dy > 6.5 and dx < 2.6):
						_set_theme_brick(grid, x, y, sinister, variant)
		"wave":
			for x in range(width):
				var y1 = 3 + int(round(sin((x + variant) * 0.42) * 2.0))
				var y2 = 8 + int(round(sin((x + variant * 2) * 0.37 + 1.4) * 2.0))
				for offset in range(-1, 2):
					_set_theme_brick(grid, x, y1 + offset, sinister, variant + x)
					_set_theme_brick(grid, x, y2 + offset, sinister, variant + x + 9)
		"rings":
			_draw_disc(grid, 8.5, 5.0, 5.5, 3.2, sinister, variant, true, 0.32)
			_draw_disc(grid, 21.5, 5.0, 5.5, 3.2, sinister, variant + 5, true, 0.32)
			_draw_disc(grid, 15.0, 9.2, 5.8, 3.3, sinister, variant + 11, true, 0.32)
		"bunny":
			_draw_disc(grid, 10.5, 3.0, 2.8, 4.3, sinister, variant, false)
			_draw_disc(grid, 19.5, 3.0, 2.8, 4.3, sinister, variant + 2, false)
			_draw_disc(grid, 15.0, 7.3, 7.8, 4.5, sinister, variant + 6, false)
			_draw_disc(grid, 12.4, 6.8, 0.9, 0.9, true, variant + 1, false)
			_draw_disc(grid, 17.6, 6.8, 0.9, 0.9, true, variant + 2, false)
			_draw_line(grid, 12, 10, 18, 10, sinister, variant + 8, 1)
		"eggs":
			for center_x in [6.0, 15.0, 24.0]:
				_draw_disc(grid, center_x, 6.5, 3.4, 4.7, sinister, variant + int(center_x), false)
				_draw_disc(grid, center_x, 6.5, 2.0, 2.9, not sinister, variant + int(center_x) + 3, true, 0.38)
		"basket":
			for center_x in [8.0, 15.0, 22.0]:
				_draw_disc(grid, center_x, 4.8, 2.5, 3.3, sinister, variant + int(center_x), false)
			_draw_rect_fill(grid, 4, 8, 21, 3, sinister, variant)
			for x in range(4, 25, 3):
				_draw_line(grid, x, 8, x, 10, not sinister, variant + x, 1)
			_draw_line(grid, 4, 8, 25, 8, not sinister, variant + 6, 1)
		"carrot":
			for y in range(3, 12):
				var spread = int(round((12 - y) * 0.7))
				for x in range(15 - spread, 15 + spread + 1):
					_set_theme_brick(grid, x, y, sinister, variant + y + x)
			for leaf in range(3):
				_draw_line(grid, 15, 1, 11 + leaf * 4, 4, false, variant + leaf, 1)
		"clown":
			_draw_disc(grid, 15.0, 7.0, 6.8, 4.2, sinister, variant, false)
			_draw_disc(grid, 7.2, 6.0, 2.7, 2.7, false, variant + 2, false)
			_draw_disc(grid, 22.8, 6.0, 2.7, 2.7, false, variant + 5, false)
			_draw_disc(grid, 15.0, 7.6, 1.1, 1.1, true, variant + 7, false)
			_draw_line(grid, 11, 10, 19, 10, sinister, variant + 9, 1)
			_draw_line(grid, 10, 3, 15, 0, false, variant + 1, 1)
			_draw_line(grid, 20, 3, 15, 0, false, variant + 4, 1)
		"car":
			_draw_rect_fill(grid, 6, 7, 17, 3, sinister, variant)
			_draw_rect_fill(grid, 10, 5, 9, 2, sinister, variant + 3)
			_draw_disc(grid, 10.0, 11.0, 3.0, 2.0, true, variant + 5, true, 0.34)
			_draw_disc(grid, 20.0, 11.0, 3.0, 2.0, true, variant + 8, true, 0.34)
		"bicycle":
			_draw_disc(grid, 8.5, 10.0, 3.6, 2.5, sinister, variant, true, 0.26)
			_draw_disc(grid, 21.5, 10.0, 3.6, 2.5, sinister, variant + 3, true, 0.26)
			_draw_line(grid, 8, 10, 13, 6, sinister, variant + 6, 1)
			_draw_line(grid, 13, 6, 18, 10, sinister, variant + 8, 1)
			_draw_line(grid, 13, 6, 16, 10, sinister, variant + 9, 1)
			_draw_line(grid, 16, 10, 21, 10, sinister, variant + 10, 1)
			_draw_line(grid, 14, 5, 16, 5, sinister, variant + 11, 1)
		"heart":
			for y in range(height):
				for x in range(width):
					var nx = (x - 14.5) / 7.4
					var ny = (y - 5.3) / 4.6
					var curve = pow(nx * nx + ny * ny - 1.0, 3.0) - nx * nx * pow(ny, 3.0)
					if curve <= 0.18:
						_set_theme_brick(grid, x, y, sinister, variant + x)
		"crown":
			_draw_rect_fill(grid, 6, 8, 18, 2, sinister, variant)
			for tip in [7, 12, 17, 22]:
				_draw_line(grid, tip, 8, tip + 2, 2 + int(tip % 2), sinister, variant + tip, 1)
				_draw_line(grid, tip + 4, 8, tip + 2, 2 + int(tip % 2), sinister, variant + tip + 2, 1)
			for jewel in [9, 15, 21]:
				_draw_disc(grid, jewel, 7.0, 1.0, 1.0, false, variant + jewel, false)
		"castle":
			_draw_rect_fill(grid, 8, 6, 14, 5, sinister, variant)
			_draw_rect_fill(grid, 5, 4, 4, 7, sinister, variant + 3)
			_draw_rect_fill(grid, 21, 4, 4, 7, sinister, variant + 5)
			for merlon in [5, 7, 9, 21, 23, 25, 11, 15, 19]:
				_draw_rect_fill(grid, merlon, 3 if merlon < 11 or merlon > 19 else 5, 1, 1, sinister, variant + merlon)
			_draw_rect_fill(grid, 13, 8, 4, 3, true, variant + 7)
		"pinwheel":
			for spoke in range(4):
				var angle = spoke * PI * 0.5 + float(variant % 5) * 0.08
				var direction = Vector2.RIGHT.rotated(angle)
				_draw_line(grid, 15, 7, int(round(15 + direction.x * 8.0)), int(round(7 + direction.y * 5.0)), sinister, variant + spoke, 2)
				_draw_line(grid, 15, 7, int(round(15 - direction.y * 6.0)), int(round(7 + direction.x * 4.0)), false, variant + spoke + 2, 2)
		"flower":
			for petal in [Vector2(10, 5), Vector2(20, 5), Vector2(10, 9), Vector2(20, 9), Vector2(15, 3), Vector2(15, 11)]:
				_draw_disc(grid, petal.x, petal.y, 3.0, 2.2, sinister, variant + int(petal.x), false)
			_draw_disc(grid, 15.0, 7.0, 2.4, 2.4, false, variant + 8, false)
		"capsule":
			_draw_disc(grid, 10.0, 7.0, 4.0, 3.0, sinister, variant, false)
			_draw_disc(grid, 20.0, 7.0, 4.0, 3.0, not sinister, variant + 3, false)
			_draw_rect_fill(grid, 10, 4, 10, 6, sinister, variant + 6)
		"ribbon":
			for x in range(width):
				var y = 6 + int(round(sin((x + variant) * 0.45) * 2.0))
				_draw_line(grid, x, y, x, y + 3, sinister, variant + x, 1)
		"rocket":
			_draw_line(grid, 15, 1, 15, 9, sinister, variant, 2)
			_draw_line(grid, 15, 1, 11, 4, sinister, variant + 2, 1)
			_draw_line(grid, 15, 1, 19, 4, sinister, variant + 4, 1)
			_draw_line(grid, 15, 8, 10, 12, false, variant + 6, 1)
			_draw_line(grid, 15, 8, 20, 12, false, variant + 8, 1)
			_draw_disc(grid, 15.0, 5.5, 1.1, 1.1, true, variant + 11, false)
		"weave":
			for y in range(height):
				for x in range(width):
					if (x / 3 + y / 2 + variant) % 2 == 0 and x % 5 < 3 and y % 4 < 2:
						_set_theme_brick(grid, x, y, sinister, variant + x + y)
		"stairs":
			for step in range(6):
				_draw_rect_fill(grid, 4 + step * 3, 10 - step, 8, 2, sinister, variant + step)
		"skull":
			_draw_disc(grid, 15.0, 6.0, 8.4, 4.7, sinister, variant, false)
			_draw_rect_fill(grid, 10, 8, 10, 4, sinister, variant + 2)
			_draw_disc(grid, 11.5, 6.0, 1.8, 1.5, true, variant + 4, false)
			_draw_disc(grid, 18.5, 6.0, 1.8, 1.5, true, variant + 6, false)
			_draw_line(grid, 14, 8, 16, 8, true, variant + 8, 1)
		"vault":
			_draw_rect_outline(grid, 7, 2, 16, 10, sinister, variant, 1)
			_draw_rect_outline(grid, 10, 4, 10, 6, sinister, variant + 2, 1)
			_draw_disc(grid, 15.0, 7.0, 2.2, 2.2, true, variant + 6, true, 0.36)
			_draw_line(grid, 15, 5, 15, 9, sinister, variant + 9, 1)
			_draw_line(grid, 13, 7, 17, 7, sinister, variant + 10, 1)
		"serpent":
			for x in range(width):
				var y = 6 + int(round(sin((x + variant) * 0.35) * 3.0))
				for thickness in range(-1, 2):
					_set_theme_brick(grid, x, y + thickness, sinister, variant + x)
				if x % 6 == 0:
					_set_theme_brick(grid, x, y - 2, true, variant + x + 3)
		"hourglass":
			_draw_line(grid, 7, 2, 22, 11, sinister, variant, 1)
			_draw_line(grid, 22, 2, 7, 11, sinister, variant + 3, 1)
			_draw_line(grid, 7, 2, 22, 2, sinister, variant + 6, 1)
			_draw_line(grid, 7, 11, 22, 11, sinister, variant + 8, 1)
		"spiral":
			_draw_rect_outline(grid, 5, 2, 20, 10, sinister, variant, 1)
			_draw_rect_outline(grid, 8, 4, 14, 6, sinister, variant + 2, 1)
			_draw_rect_outline(grid, 11, 6, 8, 2, sinister, variant + 4, 1)
			_draw_line(grid, 19, 8, 19, 10, sinister, variant + 6, 1)
		"eclipse":
			_draw_disc(grid, 13.0, 6.5, 6.0, 4.0, sinister, variant, false)
			_draw_disc(grid, 17.0, 6.5, 6.0, 4.0, true, variant + 5, false)
			_draw_disc(grid, 13.0, 6.5, 8.0, 5.2, sinister, variant + 8, true, 0.24)
		"tomb":
			_draw_rect_fill(grid, 10, 4, 10, 7, sinister, variant)
			_draw_disc(grid, 15.0, 4.0, 5.0, 2.2, sinister, variant + 2, false)
			_draw_line(grid, 15, 6, 15, 9, true, variant + 4, 1)
			_draw_line(grid, 13, 8, 17, 8, true, variant + 5, 1)
		"tower":
			_draw_rect_fill(grid, 12, 2, 6, 10, sinister, variant)
			_draw_rect_fill(grid, 10, 11, 10, 2, sinister, variant + 2)
			for spike in [12, 15, 18]:
				_draw_line(grid, spike, 2, spike + 1, 0, sinister, variant + spike, 1)
		"cage":
			_draw_rect_outline(grid, 6, 2, 18, 10, sinister, variant, 1)
			for x in range(9, 23, 3):
				_draw_line(grid, x, 2, x, 11, sinister, variant + x, 1)
			_draw_line(grid, 9, 6, 21, 6, true, variant + 4, 1)
		"altar":
			_draw_rect_fill(grid, 9, 7, 12, 3, sinister, variant)
			_draw_rect_fill(grid, 12, 4, 6, 3, sinister, variant + 2)
			_draw_line(grid, 15, 2, 15, 11, true, variant + 4, 1)
			_draw_line(grid, 11, 6, 19, 6, true, variant + 5, 1)
		"thorns":
			for x in range(3, 27, 3):
				_draw_line(grid, x, 11, x + 2, 2 + int((x + variant) % 3), sinister, variant + x, 1)
				_draw_line(grid, x + 2, 11, x + 5, 4 + int((x + variant) % 2), sinister, variant + x + 2, 1)
		"cathedral":
			_draw_rect_fill(grid, 10, 3, 10, 8, sinister, variant)
			_draw_line(grid, 10, 3, 15, 0, sinister, variant + 1, 1)
			_draw_line(grid, 20, 3, 15, 0, sinister, variant + 2, 1)
			_draw_rect_fill(grid, 7, 6, 3, 5, sinister, variant + 3)
			_draw_rect_fill(grid, 20, 6, 3, 5, sinister, variant + 5)
			_draw_line(grid, 15, 4, 15, 10, true, variant + 7, 1)
		"graveyard":
			for center in [6.0, 11.0, 16.0, 21.0]:
				_draw_rect_fill(grid, int(center) - 2, 6, 4, 5, sinister, variant + int(center))
				_draw_disc(grid, center, 6.0, 2.0, 1.2, sinister, variant + int(center) + 2, false)
			_draw_line(grid, 3, 11, 26, 11, true, variant + 9, 1)
		"idol":
			_draw_disc(grid, 15.0, 5.0, 4.0, 3.4, sinister, variant, false)
			_draw_rect_fill(grid, 12, 8, 6, 4, sinister, variant + 2)
			_draw_disc(grid, 13.3, 5.0, 0.8, 1.1, true, variant + 4, false)
			_draw_disc(grid, 16.7, 5.0, 0.8, 1.1, true, variant + 5, false)
			_draw_line(grid, 12, 10, 18, 10, true, variant + 6, 1)
		"claw":
			for finger in [7, 11, 15, 19, 23]:
				_draw_line(grid, finger, 1 + int(abs(finger - 15) * 0.15), 15, 11, sinister, variant + finger, 1)
			_draw_rect_fill(grid, 12, 10, 6, 2, sinister, variant + 3)
		"furnace":
			_draw_rect_outline(grid, 8, 3, 14, 9, sinister, variant, 1)
			_draw_rect_fill(grid, 11, 7, 8, 3, sinister, variant + 2)
			_draw_line(grid, 15, 4, 15, 6, true, variant + 4, 1)
			for vent in [10, 13, 16, 19]:
				_draw_line(grid, vent, 2, vent, 3, sinister, variant + vent, 1)
		"mask":
			_draw_disc(grid, 15.0, 6.0, 7.2, 4.4, sinister, variant, false)
			_draw_disc(grid, 11.5, 6.2, 1.7, 1.2, true, variant + 2, false)
			_draw_disc(grid, 18.5, 6.2, 1.7, 1.2, true, variant + 3, false)
			_draw_line(grid, 13, 9, 17, 9, true, variant + 4, 1)
			_draw_line(grid, 15, 5, 14, 8, true, variant + 5, 1)
		"bones":
			_draw_disc(grid, 8.0, 4.0, 2.0, 1.6, sinister, variant, false)
			_draw_disc(grid, 22.0, 4.0, 2.0, 1.6, sinister, variant + 1, false)
			_draw_disc(grid, 8.0, 10.0, 2.0, 1.6, sinister, variant + 2, false)
			_draw_disc(grid, 22.0, 10.0, 2.0, 1.6, sinister, variant + 3, false)
			_draw_line(grid, 9, 5, 21, 9, sinister, variant + 4, 1)
			_draw_line(grid, 9, 9, 21, 5, sinister, variant + 5, 1)
		"sigil":
			_draw_disc(grid, 15.0, 7.0, 7.0, 4.6, sinister, variant, true, 0.22)
			_draw_line(grid, 15, 2, 15, 12, sinister, variant + 1, 1)
			_draw_line(grid, 8, 7, 22, 7, sinister, variant + 2, 1)
			_draw_line(grid, 10, 4, 20, 10, true, variant + 3, 1)
			_draw_line(grid, 20, 4, 10, 10, true, variant + 4, 1)
		"maw":
			_draw_disc(grid, 15.0, 7.0, 8.0, 4.0, sinister, variant, false)
			for tooth in range(8):
				_draw_line(grid, 8 + tooth * 2, 8, 9 + tooth * 2, 11, true, variant + tooth, 1)
				_draw_line(grid, 9 + tooth * 2, 3, 8 + tooth * 2, 6, true, variant + tooth + 1, 1)
		_:
			for x in range(width):
				var y = 6 + int(round(sin((x + variant) * 0.5) * 2.0))
				_set_theme_brick(grid, x, y, sinister, variant + x)

	return _grid_to_layout(grid)


func _generate_phrase_layout(phrase: String, sinister: bool, variant: int) -> Array:
	var font = _tiny_font()
	var width = 30
	var height = 14
	var grid = _make_grid(width, height)
	var letters: Array = []
	var upper_phrase = phrase.to_upper()
	for index in range(upper_phrase.length()):
		letters.append(upper_phrase[index])
	var text_width = max(0, letters.size() * 4 - 1)
	var cursor = max(1, int(floor((width - text_width) * 0.5)))

	for letter in letters:
		if letter == " ":
			cursor += 2
			continue
		var glyph: Array = font.get(letter, font["A"])
		for gy in range(glyph.size()):
			var row: String = glyph[gy]
			for gx in range(row.length()):
				if row[gx] == "#":
					_set_theme_brick(grid, cursor + gx, 4 + gy, sinister, variant + gx + gy)
		cursor += 4

	for x in range(3, width - 3):
		if x % 5 != 0:
			_set_theme_brick(grid, x, 1, sinister, variant + x)
			_set_theme_brick(grid, x, 11, sinister, variant + x + 7)
	return _grid_to_layout(grid)


func _tiny_font() -> Dictionary:
	return {
		"A": ["###", "#.#", "###", "#.#", "#.#"],
		"B": ["##.", "#.#", "##.", "#.#", "##."],
		"C": ["###", "#..", "#..", "#..", "###"],
		"D": ["##.", "#.#", "#.#", "#.#", "##."],
		"E": ["###", "#..", "##.", "#..", "###"],
		"F": ["###", "#..", "##.", "#..", "#.."],
		"G": ["###", "#..", "#.#", "#.#", "###"],
		"H": ["#.#", "#.#", "###", "#.#", "#.#"],
		"I": ["###", ".#.", ".#.", ".#.", "###"],
		"K": ["#.#", "#.#", "##.", "#.#", "#.#"],
		"L": ["#..", "#..", "#..", "#..", "###"],
		"N": ["#.#", "###", "###", "###", "#.#"],
		"O": ["###", "#.#", "#.#", "#.#", "###"],
		"P": ["###", "#.#", "###", "#..", "#.."],
		"R": ["##.", "#.#", "##.", "#.#", "#.#"],
		"S": ["###", "#..", "###", "..#", "###"],
		"T": ["###", ".#.", ".#.", ".#.", ".#."],
		"U": ["#.#", "#.#", "#.#", "#.#", "###"],
		"V": ["#.#", "#.#", "#.#", "#.#", ".#."],
		"W": ["#.#", "#.#", "###", "###", "#.#"],
		"X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
		"Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
		" ": ["...", "...", "...", "...", "..."]
	}


func _make_grid(width: int, height: int) -> Array:
	var grid: Array = []
	for _row in range(height):
		var line: Array = []
		for _column in range(width):
			line.append(".")
		grid.append(line)
	return grid


func _grid_to_layout(grid: Array) -> Array:
	var layout: Array = []
	for row in grid:
		layout.append("".join(row))
	return layout


func _set_theme_brick(grid: Array, x: int, y: int, sinister: bool, variant: int) -> void:
	if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
		return
	grid[y][x] = _theme_brick_key(x, y, sinister, variant)


func _theme_brick_key(x: int, y: int, sinister: bool, variant: int) -> String:
	var candy_cycle = ["A", "B", "C", "D", "E", "S"]
	var sinister_cycle = ["S", "E", "D", "C"]
	var cycle = sinister_cycle if sinister else candy_cycle
	var index = abs(x * 5 + y * 7 + variant * 3) % cycle.size()
	var key = cycle[index]
	var explosive_gate = 15 if sinister else 23
	if (x * 11 + y * 13 + variant * 5) % explosive_gate == 0:
		key = "X"
	elif not sinister and (x + y + variant) % 9 == 0:
		key = "S"
	return key


func _draw_disc(grid: Array, center_x: float, center_y: float, radius_x: float, radius_y: float, sinister: bool, variant: int, hollow: bool = false, thickness: float = 0.24) -> void:
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var dx = (float(x) - center_x) / max(radius_x, 0.1)
			var dy = (float(y) - center_y) / max(radius_y, 0.1)
			var distance = dx * dx + dy * dy
			if hollow:
				if abs(distance - 1.0) <= thickness:
					_set_theme_brick(grid, x, y, sinister, variant + x + y)
			elif distance <= 1.0:
				_set_theme_brick(grid, x, y, sinister, variant + x + y)


func _draw_rect_fill(grid: Array, x: int, y: int, width: int, height: int, sinister: bool, variant: int) -> void:
	for row in range(y, y + height):
		for column in range(x, x + width):
			_set_theme_brick(grid, column, row, sinister, variant + row + column)


func _draw_rect_outline(grid: Array, x: int, y: int, width: int, height: int, sinister: bool, variant: int, thickness: int = 1) -> void:
	for row in range(y, y + height):
		for column in range(x, x + width):
			var border = row < y + thickness or row >= y + height - thickness or column < x + thickness or column >= x + width - thickness
			if border:
				_set_theme_brick(grid, column, row, sinister, variant + row + column)


func _draw_line(grid: Array, x0: int, y0: int, x1: int, y1: int, sinister: bool, variant: int, thickness: int = 1) -> void:
	var steps = int(max(abs(x1 - x0), abs(y1 - y0)))
	if steps <= 0:
		_set_theme_brick(grid, x0, y0, sinister, variant)
		return
	for step in range(steps + 1):
		var t = float(step) / float(steps)
		var x = int(round(lerp(float(x0), float(x1), t)))
		var y = int(round(lerp(float(y0), float(y1), t)))
		for offset_y in range(-thickness + 1, thickness):
			for offset_x in range(-thickness + 1, thickness):
				if abs(offset_x) + abs(offset_y) < thickness + 1:
					_set_theme_brick(grid, x + offset_x, y + offset_y, sinister, variant + step + offset_x + offset_y)


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
	audio_streams["music_candy"] = AudioSynth.create_music_stream("candy")
	audio_streams["music_sinister"] = AudioSynth.create_music_stream("sinister")

	music_player = AudioStreamPlayer.new()
	music_player.stream = audio_streams["music_candy"]
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

	var key_sensitivity_row = _make_slider_row("Key Sensitivity", 10.0, 100.0, 5.0)
	key_sensitivity_value_label = key_sensitivity_row["value"]
	key_sensitivity_slider = key_sensitivity_row["slider"]
	key_sensitivity_slider.value_changed.connect(_on_key_sensitivity_changed)
	options_box.add_child(key_sensitivity_row["row"])

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
	key_sensitivity_slider.value = settings["key_sensitivity"]
	key_sensitivity_value_label.text = "%d%%" % int(settings["key_sensitivity"])
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
	menu_panel.size = Vector2(480, 486)
	menu_panel.position = Vector2(size.x * 0.5 - menu_panel.size.x * 0.5, size.y * 0.5 - menu_panel.size.y * 0.5)


func _game_speed_scale() -> float:
	var level = clamp(int(settings["speed"]), 1, GAME_SPEED_LEVELS.size())
	return float(GAME_SPEED_LEVELS[level - 1])


func _max_lives() -> int:
	return 9 if settings["cheat"] else 5


func _current_theme() -> String:
	return String(current_level.get("theme", "candy"))


func _ball_speed_multiplier() -> float:
	return float(current_level.get("ball_speed_multiplier", 1.0))


func _brick_fall_speed() -> float:
	return float(current_level.get("brick_fall_speed", 0.0))


func _keyboard_sensitivity_ratio() -> float:
	return clampf(float(settings.get("key_sensitivity", 30)) / 100.0, 0.1, 1.0)


func _brick_wall_target_gap() -> float:
	var progress = float(level_index) / float(max(levels.size() - 1, 1))
	if _current_theme() == "sinister":
		return lerpf(46.0, 22.0, progress)
	return lerpf(100.0, 76.0, progress)


func _apply_brick_wall_offset() -> void:
	for brick in bricks:
		var rect: Rect2 = brick["base_rect"]
		rect.position.y += brick_wall_offset
		brick["rect"] = rect


func _configure_brick_wall_motion() -> void:
	brick_wall_offset = 0.0
	brick_wall_upper_offset = 0.0
	brick_wall_lower_offset = 0.0
	brick_wall_direction = 1.0
	if bricks.is_empty():
		return

	var lowest_brick_bottom = PLAYFIELD.position.y
	for brick in bricks:
		var rect: Rect2 = brick["base_rect"]
		lowest_brick_bottom = max(lowest_brick_bottom, rect.end.y)

	var paddle_top = float(paddle["pos"].y) - float(paddle["height"]) * 0.5
	var lowest_wall_bottom = paddle_top - _brick_wall_target_gap()
	brick_wall_lower_offset = max(0.0, lowest_wall_bottom - lowest_brick_bottom)
	_apply_brick_wall_offset()


func _powerup_weight_for(key: String) -> float:
	var meta: Dictionary = POWERUP_META[key]
	var weight = float(meta["weight"])
	if key == "bomb":
		weight *= float(current_level.get("bomb_multiplier", 1.0))
	if key == "heart" and not bool(current_level.get("allow_heart", true)):
		return 0.0
	return weight


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
		menu_hint_label.text = "Speed, keyboard feel, pause-safe toggles, and audio controls."
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
	var desired_stream = audio_streams["music_sinister"] if _current_theme() == "sinister" else audio_streams["music_candy"]
	if music_player.stream != desired_stream:
		var was_playing = music_player.playing
		music_player.stop()
		music_player.stream = desired_stream
		if was_playing and settings["music"] and state != "paused":
			music_player.play()
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


func _on_key_sensitivity_changed(value: float) -> void:
	settings["key_sensitivity"] = int(value)
	key_sensitivity_value_label.text = "%d%%" % int(value)
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
	level_index = clamp(index, 0, levels.size() - 1)
	var level = levels[level_index]
	current_level = level
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
	var column_count = 1
	for line_value in layout:
		column_count = max(column_count, String(line_value).length())
	var row_count = layout.size()
	var gap = Vector2(4.0, 4.0)
	var usable_width = PLAYFIELD.size.x - 68.0
	var usable_height = min(420.0, PLAYFIELD.size.y * 0.62)
	var brick_size = Vector2(
		floor((usable_width - (column_count - 1) * gap.x) / column_count),
		floor((usable_height - max(0, row_count - 1) * gap.y) / max(row_count, 1))
	)
	brick_size.x = clamp(brick_size.x, 32.0, 54.0)
	brick_size.y = clamp(brick_size.y, 16.0, 26.0)
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
					"base_rect": rect,
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
		"key_velocity": 0.0,
		"vx": 0.0
	}
	_configure_brick_wall_motion()
	last_paddle_x = paddle["pos"].x
	balls.clear()
	balls.append(_make_ball(Vector2(paddle["pos"].x, paddle["pos"].y - 26.0), Vector2.ZERO, true))
	state = "serve"
	state_timer = 0.0
	banner_text = ("Night %02d  %s" % [level_index + 1, level["name"]]) if _current_theme() == "sinister" else level["name"]
	banner_timer = 2.0
	_flash(Color("c7ced8", 0.48) if _current_theme() == "sinister" else Color("ffffff", 0.65), 0.35)
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
		_update_bricks(world_delta)
		_update_powerups(world_delta)
		_update_lasers(world_delta)
		_update_particles(world_delta)
		_update_floaters(world_delta)

	if state == "playing":
		_update_balls(world_delta)
	elif state == "serve":
		_update_stuck_balls()
	elif state == "level_clear" and state_timer > 1.5:
		if level_index < levels.size() - 1:
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
	var bomb_active = active_effects.has("bomb")
	var movement_slow = 0.14 if bomb_active else 1.0
	paddle["width"] = lerp(float(paddle["width"]), float(paddle["target_width"]), 1.0 - pow(0.001, delta * movement_slow))

	var move_strength = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var keyboard_sensitivity = _keyboard_sensitivity_ratio()
	var keyboard_max_speed = lerpf(260.0, 1120.0, keyboard_sensitivity)
	var keyboard_accel = lerpf(1100.0, 4200.0, keyboard_sensitivity)
	if abs(move_strength) > 0.01:
		if bomb_active:
			keyboard_max_speed *= 0.42
			keyboard_accel *= 0.45
		paddle["key_velocity"] = move_toward(float(paddle["key_velocity"]), move_strength * keyboard_max_speed, keyboard_accel * delta)
		paddle["pos"].x += float(paddle["key_velocity"]) * delta
	elif Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		paddle["key_velocity"] = 0.0
		var target_x = get_local_mouse_position().x
		target_x = clamp(target_x, PLAYFIELD.position.x + paddle["width"] * 0.5, PLAYFIELD.end.x - paddle["width"] * 0.5)
		if bomb_active:
			paddle["pos"].x = move_toward(float(paddle["pos"].x), target_x, 460.0 * delta)
		else:
			paddle["pos"].x = lerp(float(paddle["pos"].x), target_x, 1.0 - pow(0.0001, delta * movement_slow))
	else:
		paddle["key_velocity"] = move_toward(float(paddle["key_velocity"]), 0.0, keyboard_accel * 1.2 * delta)
		paddle["pos"].x += float(paddle["key_velocity"]) * delta
	paddle["pos"].x = clamp(paddle["pos"].x, PLAYFIELD.position.x + paddle["width"] * 0.5, PLAYFIELD.end.x - paddle["width"] * 0.5)
	paddle["vx"] = (paddle["pos"].x - last_paddle_x) / max(delta, 0.001)
	last_paddle_x = paddle["pos"].x


func _update_bricks(delta: float) -> void:
	var fall_speed = _brick_fall_speed()
	if fall_speed <= 0.0:
		return
	if state not in ["playing", "serve"]:
		return
	if brick_wall_lower_offset <= brick_wall_upper_offset:
		return

	var next_offset = brick_wall_offset + brick_wall_direction * fall_speed * delta
	if next_offset > brick_wall_lower_offset:
		var overflow = next_offset - brick_wall_lower_offset
		brick_wall_offset = max(brick_wall_upper_offset, brick_wall_lower_offset - overflow)
		brick_wall_direction = -1.0
	elif next_offset < brick_wall_upper_offset:
		var overflow = brick_wall_upper_offset - next_offset
		brick_wall_offset = min(brick_wall_lower_offset, brick_wall_upper_offset + overflow)
		brick_wall_direction = 1.0
	else:
		brick_wall_offset = next_offset

	_apply_brick_wall_offset()


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

	var damage = 2 if settings["cheat"] else 1
	brick["hits_left"] -= damage
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
		roll -= _powerup_weight_for(key)
		if roll <= 0.0:
			selected = key
			break
	if settings["cheat"] and selected == "bomb" and bool(current_level.get("allow_heart", true)):
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
		total += _powerup_weight_for(key)
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
		ball["vel"] = Vector2(240.0, -520.0 * _ball_speed_multiplier())
		speed = ball["vel"].length()
	var min_speed = (380.0 if active_effects.has("slow") else 460.0) * _ball_speed_multiplier()
	var max_speed = (560.0 if active_effects.has("slow") else 840.0) * _ball_speed_multiplier()
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
	level_label.text = "Level %02d/%02d    %s" % [level_index + 1, levels.size(), current_level_name]
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


func _desaturate(color: Color, amount: float) -> Color:
	var luminance = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color(
		lerpf(color.r, luminance, amount),
		lerpf(color.g, luminance, amount),
		lerpf(color.b, luminance, amount),
		color.a
	)


func _theme_color(color: Color, role: String = "body") -> Color:
	if _current_theme() != "sinister":
		return color
	var rust = Color("7a665d", color.a)
	var toned = _desaturate(color, 0.82).lerp(rust, 0.18)
	match role:
		"glow":
			toned = toned.darkened(0.58)
			toned.a *= 0.48
		"highlight":
			toned = toned.lightened(0.06)
		"field":
			toned = toned.darkened(0.22)
		"line":
			toned = toned.darkened(0.1)
		_:
			toned = toned.darkened(0.28)
	return toned


func _draw() -> void:
	var level: Dictionary = levels[level_index]
	var bg: Array = level["background"]
	var sinister = _current_theme() == "sinister"

	draw_rect(Rect2(Vector2.ZERO, size), bg[0], true)
	for index in range(14):
		var t = float(index) / 13.0
		var y = lerp(0.0, size.y, t)
		var band_color = bg[0].lerp(bg[1], t).lerp(bg[2], 0.25)
		band_color = _theme_color(band_color, "field")
		band_color.a = 0.92 if sinister else 0.85
		draw_rect(Rect2(Vector2(0.0, y), Vector2(size.x, size.y / 13.0 + 2.0)), band_color, true)

	for blob in range(7):
		var wobble = title_phase * (0.15 + blob * 0.03)
		var center = Vector2(
			200.0 + blob * 210.0 + sin(wobble * 1.6 + blob) * 80.0,
			140.0 + fmod(blob * 110.0 + title_phase * 16.0, size.y + 220.0)
		)
		var radius = 90.0 + 40.0 * sin(wobble + blob)
		var glow = _theme_color(bg[2].lerp(bg[1], float(blob % 3) / 2.0), "glow")
		glow.a = 0.05 if sinister else 0.12
		draw_circle(center + camera_offset * 0.15, radius, glow)

	for stripe in range(20):
		var offset = fmod(title_phase * 120.0 + stripe * 88.0, size.x + 300.0) - 150.0
		var stripe_color: Color = _theme_color(level["stripe"], "line")
		draw_line(
			Vector2(offset, PLAYFIELD.position.y - 110.0) + camera_offset * 0.1,
			Vector2(offset + 220.0, PLAYFIELD.end.y + 140.0) + camera_offset * 0.1,
			stripe_color,
			2.0 if sinister else 3.0
		)

	var field = PLAYFIELD
	var outer_field = Rect2(field.grow(16.0).position + camera_offset * 0.35, field.grow(16.0).size)
	var inner_field = Rect2(field.position + camera_offset * 0.2, field.size)
	draw_rect(outer_field, _theme_color(Color("2ce8ff", 0.08), "field"), true)
	draw_rect(inner_field, _theme_color(Color("0b1027", 0.86), "field"), true)
	draw_rect(inner_field, _theme_color(Color("7fdfff", 0.42), "line"), false, 3.0)

	if sinister:
		draw_rect(Rect2(Vector2.ZERO, size), Color("090909", 0.16), true)
		draw_circle(Vector2(120.0, size.y - 110.0), 210.0, Color("201716", 0.12))
		draw_circle(Vector2(size.x - 120.0, 150.0), 190.0, Color("1a1918", 0.1))

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
	var sinister = _current_theme() == "sinister"
	for brick in bricks:
		if not brick["alive"]:
			continue
		var source_rect: Rect2 = brick["rect"]
		var rect = Rect2(source_rect.position + camera_offset * 0.35, source_rect.size)
		var glow_color = _theme_color(Color(brick["glow"]), "glow")
		var body_color = _theme_color(Color(brick["color"]), "body")
		var highlight_color = _theme_color(Color(brick["highlight"]), "highlight")
		var shell_color = Color("18141f", 0.86) if sinister else Color("13213d", 0.72)
		var shadow_rect = Rect2(rect.position + Vector2(0, 2), rect.size)
		var body_rect = rect.grow(-1.0)
		var inner_rect = body_rect.grow(-2.0)
		var glow_rect = body_rect.grow(2.0)
		glow_color.a *= 0.42 if sinister else 0.35
		draw_rect(glow_rect, glow_color, true)
		draw_rect(shadow_rect, Color("02050a", 0.18 if sinister else 0.14), true)
		draw_rect(rect, shell_color, true)
		draw_rect(body_rect, body_color, true)
		draw_rect(Rect2(body_rect.position + Vector2(0, 1), Vector2(body_rect.size.x, max(3.0, body_rect.size.y * 0.24))), highlight_color, true)
		draw_rect(inner_rect, body_color.darkened(0.2), false, 1.0)
		if sinister:
			draw_line(body_rect.position + Vector2(4, body_rect.size.y * 0.38), body_rect.end - Vector2(4, body_rect.size.y * 0.38), Color("f4eee5", 0.06), 1.0)
			draw_line(body_rect.position + Vector2(body_rect.size.x * 0.25, 3), body_rect.position + Vector2(body_rect.size.x * 0.72, body_rect.size.y - 4), Color("141414", 0.18), 1.0)
		if brick["hits_left"] < brick["max_hits"]:
			var crack_color = Color("e7dfd7", 0.5 if sinister else 0.65)
			draw_line(body_rect.position + Vector2(8, 7), body_rect.end - Vector2(8, 10), crack_color, 2.0)
			draw_line(body_rect.position + Vector2(body_rect.size.x * 0.58, 6), body_rect.position + Vector2(body_rect.size.x * 0.36, body_rect.size.y - 6), crack_color, 2.0)
		if brick.get("explosive", false):
			var explosive_color = Color("f4e6d6", 0.75 if sinister else 1.0)
			draw_line(body_rect.position + Vector2(10, body_rect.size.y * 0.5), body_rect.end - Vector2(10, body_rect.size.y * 0.5), explosive_color, 2.0)
			draw_line(body_rect.position + Vector2(body_rect.size.x * 0.5, 6), body_rect.position + Vector2(body_rect.size.x * 0.5, body_rect.size.y - 6), explosive_color, 2.0)


func _draw_paddle() -> void:
	var rect = Rect2(
		Vector2(paddle["pos"].x - paddle["width"] * 0.5, paddle["pos"].y - paddle["height"] * 0.5) + camera_offset,
		Vector2(paddle["width"], paddle["height"])
	)
	var bomb_active = active_effects.has("bomb")
	var laser_active = active_effects.has("laser")
	var shell_color = Color("442a50") if bomb_active else Color("2a3142")
	var body_color = Color("8a5cff") if bomb_active else Color("ff8a23")
	var stripe_color = Color("b46cff") if bomb_active else Color("ff4eb4")
	var endcap_color = Color("2ed6ff")
	var glow_color = Color("ff5bcb", 0.06) if bomb_active else Color("ffe66c", 0.05)
	var shadow_rect = Rect2(rect.position + Vector2(0, 2), rect.size)
	var body_rect = rect.grow(-1.0)
	var lane_rect = Rect2(body_rect.position + Vector2(14, 4), Vector2(body_rect.size.x - 28, body_rect.size.y - 8))
	var endcap_width = clamp(body_rect.size.x * 0.085, 16.0, 22.0)
	var left_cap = Rect2(body_rect.position, Vector2(endcap_width, body_rect.size.y))
	var right_cap = Rect2(body_rect.end - Vector2(endcap_width, body_rect.size.y), Vector2(endcap_width, body_rect.size.y))
	draw_rect(rect.grow(4.0), glow_color, true)
	draw_rect(shadow_rect, Color("02050a", 0.12), true)
	draw_rect(rect, shell_color, true)
	draw_rect(body_rect, body_color, true)
	draw_rect(Rect2(body_rect.position + Vector2(0, 1), Vector2(body_rect.size.x, max(4.0, body_rect.size.y * 0.26))), Color("fff5c7"), true)
	draw_rect(lane_rect, stripe_color, true)
	draw_rect(Rect2(lane_rect.position + Vector2(0, 3), Vector2(lane_rect.size.x, 3)), Color("fff8bf", 0.9), true)
	draw_rect(Rect2(lane_rect.position + Vector2(0, lane_rect.size.y - 5), Vector2(lane_rect.size.x, 3)), Color("ff7a1f", 0.85), true)
	draw_rect(Rect2(body_rect.position + Vector2(4, 4), body_rect.size - Vector2(8, 8)), body_color.darkened(0.16), false, 1.0)
	draw_rect(left_cap, endcap_color, true)
	draw_rect(right_cap, endcap_color, true)
	draw_rect(Rect2(left_cap.position + Vector2(0, 1), Vector2(left_cap.size.x, max(4.0, left_cap.size.y * 0.28))), Color("7cf4ff"), true)
	draw_rect(Rect2(right_cap.position + Vector2(0, 1), Vector2(right_cap.size.x, max(4.0, right_cap.size.y * 0.28))), Color("7cf4ff"), true)
	if active_effects.has("laser"):
		var turret_size = Vector2(10, 8)
		var left_turret = Rect2(Vector2(left_cap.position.x + 3, body_rect.position.y - 5), turret_size)
		var right_turret = Rect2(Vector2(right_cap.end.x - turret_size.x - 3, body_rect.position.y - 5), turret_size)
		for turret in [left_turret, right_turret]:
			draw_rect(turret, Color("4a5168"), true)
			draw_rect(turret.grow(-1.0), Color("fff6a4"), true)
			draw_rect(Rect2(turret.position + Vector2(0, 1), Vector2(turret.size.x, 2)), Color("fffce1"), true)


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
		var shell_rect = Rect2(
			pickup["pos"] + camera_offset * 0.4 + Vector2(0, sin(pickup["wobble"]) * 4.0) - Vector2(20, 11),
			Vector2(40, 22)
		)
		var body_rect = shell_rect.grow(-2.0)
		var inner_rect = body_rect.grow(-2.0)
		var plate_color = Color("2a3049", 0.32) if pickup.get("bad", false) else Color("2e3650", 0.24)
		var shadow_rect = Rect2(shell_rect.position + Vector2(0, 2), shell_rect.size)
		var highlight_color = Color("fff4d8") if pickup.get("bad", false) else Color("ffffff")
		draw_rect(shell_rect.grow(4.0), Color(pickup["color"], 0.08), true)
		draw_rect(shadow_rect, Color("03050a", 0.12), true)
		draw_rect(shell_rect, plate_color, true)
		draw_rect(body_rect, pickup["color"], true)
		draw_rect(Rect2(body_rect.position + Vector2(0, 1), Vector2(body_rect.size.x, max(3.0, body_rect.size.y * 0.28))), highlight_color, true)
		draw_rect(inner_rect, Color(pickup["color"]).darkened(0.18), false, 1.0)
		draw_string(
			ThemeDB.fallback_font,
			body_rect.position + Vector2(body_rect.size.x * 0.5 - 5.0, body_rect.size.y * 0.72),
			pickup["label"],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			17,
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
			if level_index < levels.size() - 1:
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
	var base_speed = 560.0 * _ball_speed_multiplier()
	for ball in balls:
		if not ball["stuck"]:
			continue
		var spread = rng.randf_range(-0.38, 0.38)
		ball["stuck"] = false
		ball["vel"] = Vector2(spread * 260.0 * _ball_speed_multiplier(), -base_speed)
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
	settings["key_sensitivity"] = int(config.get_value("settings", "key_sensitivity", settings["key_sensitivity"]))
	settings["cheat"] = bool(config.get_value("settings", "cheat", settings["cheat"]))
	settings["music"] = bool(config.get_value("settings", "music", settings["music"]))
	settings["sfx"] = bool(config.get_value("settings", "sfx", settings["sfx"]))
	settings["volume"] = float(config.get_value("settings", "volume", settings["volume"]))


func _save_progress() -> void:
	high_score = max(high_score, score)
	var config = ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.set_value("settings", "speed", settings["speed"])
	config.set_value("settings", "key_sensitivity", settings["key_sensitivity"])
	config.set_value("settings", "cheat", settings["cheat"])
	config.set_value("settings", "music", settings["music"])
	config.set_value("settings", "sfx", settings["sfx"])
	config.set_value("settings", "volume", settings["volume"])
	config.save(SAVE_PATH)
