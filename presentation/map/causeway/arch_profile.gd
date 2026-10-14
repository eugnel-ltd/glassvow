extends RefCounted
## The underside of a causeway at a station along its route: solid piers and
## segmental arches on an ordinary deck, one complete arch under a raised
## crossing. The archive's `stone_bridge/profile.gd`, its absolute heights read
## from the style (`presets.gd`).
static func soffit(height: float, station: float, total: float, raised: bool,
		settings: Dictionary) -> float:
	var thickness: float = settings["crown_thickness"]
	var pier_foot: float = settings["pier_foot"]
	if raised:
		var end: float = minf(station, total - station)
		var pier_half: float = settings["pier_width"]
		var pier: float = pier_half * .5
		if end <= pier:
			return pier_foot
		var half_opening: float = maxf(.3, total * .5 - pier)
		var unit: float = (station - total * .5) / half_opening
		var sag: float = settings["crossing_arch_rise"]
		return height - thickness - sag + sag * sqrt(maxf(0.0, 1.0 - unit * unit))
	var spacing: float = settings["arch_spacing"]
	var pier_width: float = settings["pier_width"]
	var arches: int = maxi(1, roundi(total / spacing))
	var bay: float = total / arches
	var half_opening: float = maxf(.3, (bay - pier_width) * .5)
	var local: float = fposmod(station, bay) - bay * .5
	if absf(local) >= half_opening:
		return pier_foot
	var crown: float = height - thickness
	var spring_cap: float = settings["spring_cap"]
	var spring: float = minf(spring_cap, crown - .25)
	var unit: float = local / half_opening
	return spring + (crown - spring) * sqrt(maxf(0.0, 1.0 - unit * unit))
