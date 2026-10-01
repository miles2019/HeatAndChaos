class_name Pal
extends RefCounted
## Industrial-neon palette. Colours double as gameplay language (see design doc §10.5).

const CYAN := Color("19e6ff")      # electricity / control
const LIME := Color("8dff2a")      # poison / acid
const RED := Color("ff3b1f")       # heat / explosion / danger
const VIOLET := Color("a24bff")    # instability / space distortion
const WHITE := Color("ffffff")     # impact / crit / hit-stop
const AMBER := Color("ffb02e")     # warm safe rooms / UI accents
const RUST := Color("6b3320")
const RUST_DARK := Color("2a1712")
const STEEL := Color("3a3f4d")
const STEEL_DARK := Color("1b1e27")
const BG := Color("0e0b12")

static func heat_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return CYAN.lerp(AMBER, t * 2.0)
	return AMBER.lerp(RED, (t - 0.5) * 2.0)
