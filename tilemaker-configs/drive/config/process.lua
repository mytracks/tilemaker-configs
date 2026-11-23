-- The drive tile set: roads and buildings for the driving game osmDrive, at zoom 14 only.
--
-- The tile carries what is mapped and readable, as numbers in meters and km/h, and nothing
-- derived: no height from levels, no width from lanes or class. The game estimates what is
-- missing, so a better estimate never needs a new build. See the README for the schema.

node_keys = {}

function init_function()
end

function exit_function()
end

function node_function(node)
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

	local lanes = PlainNumber(way:Find("lanes"))
	if lanes~=nil and lanes==math.floor(lanes) and lanes>=1 and lanes<=16 then
		way:AttributeNumeric("lanes", lanes)
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
