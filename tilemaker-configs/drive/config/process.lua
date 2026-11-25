-- The drive tile set: roads and buildings for the driving game osmDrive, at zoom 14 only.
--
-- The tile carries what is mapped and readable, as numbers in meters and km/h, and nothing
-- derived: no height from levels, no width from lanes or class. The game estimates what is
-- missing, so a better estimate never needs a new build. See the README for the schema.

-- Nodes with one of these keys are looked at: what stands at a road and says who drives when.
node_keys = { "highway", "traffic_calming" }

function init_function()
end

function exit_function()
end

-- What a node on a road is, for the layer of points.
point_kinds = {
	traffic_signals = "signals", stop = "stop", give_way = "give_way", crossing = "crossing",
	mini_roundabout = "mini_roundabout", turning_circle = "turning_circle", turning_loop = "turning_circle"
}

-- The direction of travel a sign or signal on a way's node is for, along the way's line or
-- against it. Compass points and angles say where a sign faces, not which traffic it is for.
point_directions = { forward = "forward", backward = "backward", both = "both" }

function node_function(node)
	local kind = point_kinds[node:Find("highway")]
	local calming = node:Find("traffic_calming")
	if calming=="no" then calming = "" end
	if kind==nil then
		if calming=="" then return end
		kind = "calming"
	end

	node:Layer("road_point", false)
	node:Attribute("kind", kind)
	SetText(node, "calming", calming)

	local direction = node:Find("direction")
	if kind=="signals" and node:Find("traffic_signals:direction")~="" then
		direction = node:Find("traffic_signals:direction")
	end
	SetText(node, "direction", point_directions[direction] or "")

	if kind=="crossing" then
		local crossing = node:Find("crossing")
		SetText(node, "crossing", crossing)
		SetText(node, "markings", node:Find("crossing:markings"))
		if crossing=="traffic_signals" or node:Find("crossing:signals")=="yes" then
			node:AttributeNumeric("signals", 1)
		end
		if node:Find("crossing:island")=="yes" then
			node:AttributeNumeric("island", 1)
		end
	end
end

-- The game's road classes. Roads of one class are alike enough for it to share a default width.
road_classes = {
	motorway = "motorway", trunk = "trunk", primary = "primary", secondary = "secondary",
	tertiary = "tertiary",
	unclassified = "minor", residential = "minor", living_street = "minor", road = "minor",
	service = "service", track = "track", busway = "busway"
}

-- A link road has the class of the road it belongs to and is marked as a link.
link_classes = {
	motorway_link = "motorway", trunk_link = "trunk", primary_link = "primary",
	secondary_link = "secondary", tertiary_link = "tertiary"
}

-- Tags that say who may use a way, the most specific first: the first one present decides.
access_keys = { "motorcar", "motor_vehicle", "vehicle", "access" }

-- A roof over a road without a tunnel: the road passes through or under a building.
covered_values = { yes = true, arcade = true, colonnade = true }

-- The number at the start of a value and the unit after it, or nil. A decimal comma counts as a
-- point; anything else in front of or between them makes the value unreadable.
function NumberAndUnit(value)
	local number, unit = string.match(value, "^%s*(%d+[%.,]?%d*)%s*(.-)%s*$")
	if number==nil then return nil end
	number = tonumber((string.gsub(number, ",", ".")))
	if number==nil then return nil end
	return number, string.lower(unit)
end

-- A length in meters, rounded to 0.1 m, or nil if it cannot be read.
function Meters(value)
	if value=="" then return nil end
	-- Feet and inches as in 12'6": too rare for more than the feet.
	local feet = string.match(value, "^%s*(%d+%.?%d*)%s*'")
	local number, unit
	if feet~=nil then
		number, unit = tonumber(feet), "ft"
	else
		number, unit = NumberAndUnit(value)
	end
	if number==nil then return nil end
	if unit=="" or unit=="m" or unit=="meter" or unit=="metre" or unit=="meters" or unit=="metres" then
		-- meters already
	elseif unit=="ft" or unit=="feet" or unit=="foot" then
		number = number * 0.3048
	else
		return nil
	end
	return math.floor(number * 10 + 0.5) / 10
end

-- A speed in km/h as a whole number, or nil: implicit limits ("DE:urban"), "none", "signals"
-- and "walk" are not numbers, and the tile guesses none.
function KilometersPerHour(value)
	if value=="" then return nil end
	local number, unit = NumberAndUnit(value)
	if number==nil then return nil end
	if unit=="" or unit=="km/h" or unit=="kmh" or unit=="kph" then
		-- km/h already
	elseif unit=="mph" then
		number = number * 1.609344
	elseif unit=="knots" then
		number = number * 1.852
	else
		return nil
	end
	if number<=0 then return nil end
	return math.floor(number + 0.5)
end

-- A plain number such as a count of lanes or levels, or nil.
function PlainNumber(value)
	if value=="" then return nil end
	local number, unit = NumberAndUnit(value)
	if number==nil or unit~="" then return nil end
	return number
end

-- A whole number of lanes, or nil.
function Lanes(value)
	local lanes = PlainNumber(value)
	if lanes~=nil and lanes==math.floor(lanes) and lanes>=1 and lanes<=16 then
		return lanes
	end
	return nil
end

-- What the lanes of one direction are for, as mapped: "left|through|through;right". Lower case
-- and without spaces; nil if it holds anything but the words, ";" and "|", or is very long.
function TurnLanes(value)
	if value=="" then return nil end
	local turns = string.lower((string.gsub(value, "%s", "")))
	if #turns>120 or string.find(turns, "[^a-z_;|]") then return nil end
	return turns
end

-- Where a way's line lies among its lanes, as mapped: "right_of:1", "middle_of:2",
-- "transition". Nil for anything else.
function Placement(value)
	if value=="transition" then return value end
	if string.match(value, "^left_of:%d+$") or string.match(value, "^right_of:%d+$") or string.match(value, "^middle_of:%d+$") then
		return value
	end
	return nil
end

sidewalk_values = { yes = "yes", no = "no", none = "no", separate = "separate" }

-- Whether the road has a pavement on its left and on its right, seen along its line: "yes",
-- "no", or "separate" for one that is mapped as a way of its own. Nil where nothing is said.
-- The tags of one side come before the tag for both.
function Sidewalks(way)
	local left, right
	local sidewalk = way:Find("sidewalk")
	if sidewalk=="both" or sidewalk=="yes" then
		left, right = "yes", "yes"
	elseif sidewalk=="left" then
		left, right = "yes", "no"
	elseif sidewalk=="right" then
		left, right = "no", "yes"
	elseif sidewalk=="no" or sidewalk=="none" then
		left, right = "no", "no"
	elseif sidewalk=="separate" then
		left, right = "separate", "separate"
	end
	local both = sidewalk_values[way:Find("sidewalk:both")]
	if both~=nil then
		left, right = both, both
	end
	left = sidewalk_values[way:Find("sidewalk:left")] or left
	right = sidewalk_values[way:Find("sidewalk:right")] or right
	return left, right
end

priority_roads = { designated = true, yes_unposted = true, ["end"] = true }

function SetText(way, name, value)
	if value~="" then
		way:Attribute(name, value)
	end
end

function SetNumber(way, name, value)
	if value~=nil then
		way:AttributeNumeric(name, value)
	end
end

-- Whether motor vehicles are kept out. A private way is kept: the game does not ask whose it is.
function IsClosedToCars(way)
	for _,key in ipairs(access_keys) do
		local value = way:Find(key)
		if value~="" then
			return value=="no"
		end
	end
	return false
end

function IsYes(value)
	return value~="" and value~="no" and value~="false" and value~="0"
end

function WriteRoad(way, highway)
	local class = road_classes[highway]
	local link = false
	if class==nil then
		class = link_classes[highway]
		link = class~=nil
	end
	-- Everything else is not for cars: paths, steps, pedestrian zones, ways being built.
	if class==nil then return end
	-- A square or a wide place mapped as an area has no course to drive along.
	if way:Find("area")=="yes" then return end
	if IsClosedToCars(way) then return end

	way:Layer("road", false)
	way:Attribute("class", class)
	if link then
		way:AttributeNumeric("link", 1)
	end

	local tunnel = way:Find("tunnel")
	local structure = ""
	if tunnel=="building_passage" then
		structure = "passage"
	elseif IsYes(way:Find("bridge")) then
		structure = "bridge"
	elseif IsYes(tunnel) then
		structure = "tunnel"
	elseif covered_values[way:Find("covered")] then
		structure = "passage"
	end
	SetText(way, "structure", structure)

	local layer = tonumber(way:Find("layer"))
	if layer~=nil and layer==math.floor(layer) and layer~=0 and math.abs(layer)<=10 then
		way:AttributeNumeric("layer", layer)
	end

	local roundabout = way:Find("junction")=="roundabout" or way:Find("junction")=="circular"
	if roundabout then
		way:AttributeNumeric("roundabout", 1)
	end
	local oneway = way:Find("oneway")
	if oneway=="-1" or oneway=="reverse" then
		way:AttributeNumeric("oneway", -1)
	elseif oneway=="yes" or oneway=="1" or oneway=="true" then
		way:AttributeNumeric("oneway", 1)
	elseif oneway=="" and (roundabout or highway=="motorway") then
		-- Implied where OpenStreetMap implies it.
		way:AttributeNumeric("oneway", 1)
	end

	SetNumber(way, "lanes", Lanes(way:Find("lanes")))
	-- Lanes per direction of the way's line, the lane both directions turn from, and what each
	-- lane is for. Forward is along the line, also where "oneway" is -1.
	SetNumber(way, "lanes_forward", Lanes(way:Find("lanes:forward")))
	SetNumber(way, "lanes_backward", Lanes(way:Find("lanes:backward")))
	SetNumber(way, "lanes_both_ways", Lanes(way:Find("lanes:both_ways")))
	SetText(way, "turn_lanes", TurnLanes(way:Find("turn:lanes")) or "")
	SetText(way, "turn_lanes_forward", TurnLanes(way:Find("turn:lanes:forward")) or "")
	SetText(way, "turn_lanes_backward", TurnLanes(way:Find("turn:lanes:backward")) or "")
	SetText(way, "placement", Placement(way:Find("placement")) or "")
	if way:Find("lane_markings")=="no" then
		way:AttributeNumeric("lane_markings", 0)
	end

	local left, right = Sidewalks(way)
	SetText(way, "sidewalk_left", left or "")
	SetText(way, "sidewalk_right", right or "")

	-- Two lines that are the two carriageways of one street have its name or number in common.
	SetText(way, "name", way:Find("name"))
	SetText(way, "ref", way:Find("ref"))
	if priority_roads[way:Find("priority_road")] then
		way:Attribute("priority_road", way:Find("priority_road"))
	end
	SetNumber(way, "width", Meters(way:Find("width")))
	SetNumber(way, "maxspeed", KilometersPerHour(way:Find("maxspeed")))
	SetText(way, "surface", way:Find("surface"))
	if class=="service" then
		SetText(way, "service", way:Find("service"))
	end
end

function WriteBuilding(way, building, part)
	local isPart = building==""
	local kind = building
	if isPart then
		kind = part
	end
	-- Nothing of a building below the ground is seen or in the way.
	if way:Find("location")=="underground" then return end

	way:Layer("building", true)
	if isPart then
		way:AttributeNumeric("part", 1)
	end
	if kind~="yes" then
		way:Attribute("kind", kind)
	end

	local height = Meters(way:Find("height"))
	if height==nil then height = Meters(way:Find("building:height")) end
	SetNumber(way, "height", height)
	local minHeight = Meters(way:Find("min_height"))
	if minHeight==nil then minHeight = Meters(way:Find("building:min_height")) end
	SetNumber(way, "min_height", minHeight)
	SetNumber(way, "levels", PlainNumber(way:Find("building:levels")))
	SetNumber(way, "min_level", PlainNumber(way:Find("building:min_level")))

	SetText(way, "roof_shape", way:Find("roof:shape"))
	SetNumber(way, "roof_height", Meters(way:Find("roof:height")))
	SetNumber(way, "roof_levels", PlainNumber(way:Find("roof:levels")))
	SetText(way, "colour", way:Find("building:colour"))
	SetText(way, "roof_colour", way:Find("roof:colour"))
end

function way_function(way)
	local highway = way:Find("highway")
	if highway~="" then
		WriteRoad(way, highway)
		return
	end

	local building = way:Find("building")
	local part = way:Find("building:part")
	if building=="no" then building = "" end
	if part=="no" then part = "" end
	if (building~="" or part~="") and way:IsClosed() then
		WriteBuilding(way, building, part)
	end
end
