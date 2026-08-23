extends RefCounted
class_name UITheme

## ═══════════════════════════════════════════════════════════════════════════════
##  UI THEME — one design system for every screen in the game.
##
##  The old version built a fresh Theme object every time a screen opened, with
##  three styles in it, and every screen then hard-coded its own colours and
##  sizes on top. That is how a game ends up with five different golds and four
##  different button heights.
##
##  This is a real token system: colours, type scale, spacing and radii are
##  defined ONCE here, the Theme is built ONCE and cached, and screens compose
##  from the same helpers. Change a token, and every screen changes with it.
##
##  Mobile-first sizing throughout — 48 px minimum touch targets (the accepted
##  floor for a reliable thumb press), generous spacing, heavy contrast so the
##  UI survives outdoor daylight on a phone screen.
## ═══════════════════════════════════════════════════════════════════════════════

# ── Colour tokens ─────────────────────────────────────────────────────────────
const INK          := Color(0.055, 0.070, 0.098)   ## deepest background
const SURFACE      := Color(0.094, 0.118, 0.157)   ## panels
const SURFACE_HIGH := Color(0.145, 0.180, 0.235)   ## raised panels, buttons
const SURFACE_LOW  := Color(0.070, 0.088, 0.120)   ## wells, insets

const GOLD         := Color(0.851, 0.706, 0.267)   ## primary accent, royalty
const GOLD_DIM     := Color(0.580, 0.470, 0.170)
const EMBER        := Color(0.918, 0.412, 0.208)   ## danger, execution, fire
const MOSS         := Color(0.325, 0.686, 0.365)   ## resources, safe, healthy
const FROST        := Color(0.365, 0.667, 0.898)   ## water, information
const BLOOD        := Color(0.792, 0.208, 0.227)   ## HP, kills, the Traitor
const PLUM         := Color(0.545, 0.298, 0.741)   ## curse, magic, the throne

const TEXT         := Color(0.957, 0.945, 0.910)
const TEXT_MUTED   := Color(0.639, 0.671, 0.714)
const TEXT_FAINT   := Color(0.420, 0.455, 0.510)

## Trust Colour System (GDD §11) — green to orange, and NEVER red. The system
## hints; it must never confirm a Traitor, or the whole deduction loop collapses.
const TRUST_GREEN  := Color(0.298, 0.686, 0.314)
const TRUST_YELLOW := Color(1.000, 0.757, 0.027)
const TRUST_ORANGE := Color(1.000, 0.596, 0.000)

# ── Spacing / geometry tokens ─────────────────────────────────────────────────
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 16
const SPACE_LG := 24
const SPACE_XL := 40

const RADIUS_SM := 8
const RADIUS_MD := 14
const RADIUS_LG := 22
const RADIUS_PILL := 999

## Minimum comfortable touch target on a phone.
const TOUCH_MIN := 56

# ── Type scale ────────────────────────────────────────────────────────────────
const FONT_DISPLAY := 64
const FONT_TITLE   := 40
const FONT_HEADING := 28
const FONT_BODY    := 20
const FONT_LABEL   := 17
const FONT_MICRO   := 14

static var _theme: Theme = null


## The shared Theme. Built once, reused by every screen.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = FONT_BODY

	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	t.set_stylebox("normal", "Button", button_style(SURFACE_HIGH, GOLD_DIM))
	t.set_stylebox("hover", "Button", button_style(SURFACE_HIGH.lightened(0.12), GOLD))
	t.set_stylebox("pressed", "Button", button_style(SURFACE_LOW, GOLD))
	t.set_stylebox("disabled", "Button", button_style(SURFACE_LOW, TEXT_FAINT))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", TEXT_FAINT)
	t.set_font_size("font_size", "Button", FONT_BODY)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_constant("shadow_outline_size", "Label", 2)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = SURFACE_LOW
	bar_bg.set_corner_radius_all(RADIUS_SM)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = MOSS
	bar_fill.set_corner_radius_all(RADIUS_SM)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	_theme = t
	return t


## Backwards-compatible entry point used by existing screens.
static func apply_rpg_theme(root_control: Control) -> void:
	root_control.theme = get_theme()


# ═══════════════════════════════════════════════════════════════════════════════
#  STYLE BUILDERS
# ═══════════════════════════════════════════════════════════════════════════════

static func panel_style(bg: Color = SURFACE, border: Color = GOLD_DIM,
		radius: int = RADIUS_MD, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = SPACE_MD
	sb.content_margin_right = SPACE_MD
	sb.content_margin_top = SPACE_MD
	sb.content_margin_bottom = SPACE_MD
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func button_style(bg: Color, border: Color, radius: int = RADIUS_MD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = SPACE_LG
	sb.content_margin_right = SPACE_LG
	sb.content_margin_top = SPACE_MD
	sb.content_margin_bottom = SPACE_MD
	return sb


static func flat_style(bg: Color, radius: int = RADIUS_SM) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb


# ═══════════════════════════════════════════════════════════════════════════════
#  COMPONENT HELPERS — so every screen builds the same widgets the same way
# ═══════════════════════════════════════════════════════════════════════════════

static func title(text: String, size: int = FONT_TITLE, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Wrapping text. Use for blurbs and paragraphs — anywhere the string is long
## enough that it SHOULD flow onto a second line.
static func body(text: String, size: int = FONT_LABEL, color: Color = TEXT_MUTED) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Single-line text. Use for labels, values, stat names, anything in a row.
##
## This exists because `body()` wraps by default, and a wrapping Label inside a
## narrow HBox reports a tall minimum size — which is how the HUD's four
## resource rows inflated the treasury panel to 341px when its content needs
## about 130, and how "KING" once rendered as a vertical stack of letters.
## If the text is not a sentence, it wants this, not body().
static func line(text: String, size: int = FONT_LABEL, color: Color = TEXT_MUTED) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Primary call-to-action. Gold, large, unmissable.
static func primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH_MIN + 12)
	b.add_theme_font_size_override("font_size", FONT_HEADING)
	b.add_theme_stylebox_override("normal", button_style(GOLD, GOLD.lightened(0.25), RADIUS_LG))
	b.add_theme_stylebox_override("hover", button_style(GOLD.lightened(0.14), Color.WHITE, RADIUS_LG))
	b.add_theme_stylebox_override("pressed", button_style(GOLD_DIM, GOLD, RADIUS_LG))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	return b


static func secondary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH_MIN)
	b.add_theme_font_size_override("font_size", FONT_BODY)
	return b


static func ghost_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH_MIN - 8)
	b.add_theme_font_size_override("font_size", FONT_LABEL)
	b.add_theme_stylebox_override("normal", button_style(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.14)))
	b.add_theme_stylebox_override("hover", button_style(Color(1, 1, 1, 0.12), GOLD_DIM))
	b.add_theme_stylebox_override("pressed", button_style(Color(0, 0, 0, 0.25), GOLD_DIM))
	b.add_theme_color_override("font_color", TEXT_MUTED)
	return b


static func panel(bg: Color = SURFACE, border: Color = GOLD_DIM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border))
	return p


## A labelled stat bar (HP, hunger, thirst, build progress).
static func stat_bar(fill: Color, height: int = 14) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.add_theme_stylebox_override("background", flat_style(Color(0, 0, 0, 0.45), RADIUS_PILL))
	pb.add_theme_stylebox_override("fill", flat_style(fill, RADIUS_PILL))
	pb.max_value = 100.0
	pb.value = 100.0
	return pb


## A small coloured pill used for counters (coins, resources, squads alive).
static func chip(text: String, tint: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat_style(Color(tint.r, tint.g, tint.b, 0.20), RADIUS_PILL))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", SPACE_XS)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.add_theme_stylebox_override("panel", flat_style(tint, RADIUS_PILL))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_LABEL)
	l.add_theme_color_override("font_color", TEXT)
	h.add_child(dot)
	h.add_child(l)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", SPACE_SM)
	m.add_theme_constant_override("margin_right", SPACE_SM)
	m.add_theme_constant_override("margin_top", SPACE_XS)
	m.add_theme_constant_override("margin_bottom", SPACE_XS)
	m.add_child(h)
	p.add_child(m)
	return p


## Full-screen vertical gradient backdrop. Every screen sits on one, which is
## most of what makes a set of screens feel like one product.
static func backdrop(top: Color = Color(0.086, 0.114, 0.157),
		bottom: Color = Color(0.035, 0.055, 0.078)) -> ColorRect:
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
void fragment() {
	vec3 c = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, UV.y));
	// Vignette keeps the eye on the centre of the screen, which matters more on
	// a phone than on a monitor because the whole thing is in peripheral view.
	float d = distance(UV, vec2(0.5));
	c *= 1.0 - smoothstep(0.35, 0.95, d) * vignette;
	COLOR = vec4(c, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("top_color", top)
	mat.set_shader_parameter("bottom_color", bottom)
	mat.set_shader_parameter("vignette", 0.45)
	cr.material = mat
	return cr


## Role accent colour — used consistently across select, HUD and post-match.
static func role_color(role: int) -> Color:
	match role:
		Constants.Role.KING: return GOLD
		Constants.Role.QUEEN: return PLUM
		Constants.Role.SOLDIER_A: return FROST
		Constants.Role.SOLDIER_B: return MOSS
	return TEXT_MUTED


static func role_name(role: int) -> String:
	match role:
		Constants.Role.KING: return "King"
		Constants.Role.QUEEN: return "Queen"
		Constants.Role.SOLDIER_A: return "Soldier A"
		Constants.Role.SOLDIER_B: return "Soldier B"
	return "Unit"


static func resource_color(type: int) -> Color:
	match type:
		Constants.ResourceType.WOOD:  return Color(0.62, 0.44, 0.26)
		Constants.ResourceType.STONE: return Color(0.62, 0.64, 0.68)
		Constants.ResourceType.FOOD:  return Color(0.88, 0.42, 0.32)
		Constants.ResourceType.WATER: return FROST
		Constants.ResourceType.METAL: return Color(0.78, 0.80, 0.86)
		Constants.ResourceType.HERBS: return MOSS
	return TEXT_MUTED


static func resource_name(type: int) -> String:
	match type:
		Constants.ResourceType.WOOD:  return "Wood"
		Constants.ResourceType.STONE: return "Stone"
		Constants.ResourceType.FOOD:  return "Food"
		Constants.ResourceType.WATER: return "Water"
		Constants.ResourceType.METAL: return "Metal"
		Constants.ResourceType.HERBS: return "Herbs"
	return "?"
