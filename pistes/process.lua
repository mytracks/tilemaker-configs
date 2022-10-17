-- Nodes will only be processed if one of these keys is present

node_keys = { "piste", "aerialway" }

-- Initialize Lua logic

function init_function()
end

-- Finalize Lua logic()
function exit_function()
end

-- Assign nodes to a layer, and set attributes, based on OSM tags

function TrySetAttribute(obj, name)
	local value = obj:Find(name)
	if value~="" then
		obj:Attribute(name, value)
	end
end

function TrySetPisteAttribute(obj, name)
	local value = obj:Find("piste:" .. name)
	if value~="" then
		obj:Attribute(name, value)
	end
end

function node_function(node)
	local piste = node:Find("piste")
	if piste~="" then
		node:Layer("piste", false)
		TrySetAttribute(node, "name")
		TrySetPisteAttribute(node, "grooming")
		TrySetPisteAttribute(node, "difficulty")
	end

	local aerialway = node:Find("aerialway")
	if aerialway~="" then
		node:Layer("aerialway", false)
		node:Attribute("class", aerialway)
		node:Attribute("name", node:Find("name"))
	end
end

-- Similarly for ways

function way_function(way)
	local piste = way:Find("piste:type")
	if piste~="" then
		way:Layer("piste", false)
		way:Attribute("class", piste)
		TrySetAttribute(way, "name")
		TrySetAttribute(way, "area")
		TrySetPisteAttribute(way, "grooming")
		TrySetPisteAttribute(way, "difficulty")
	end

	local aerialway = way:Find("aerialway")
	if aerialway~="" then
		way:Layer("aerialway", false)
		way:Attribute("class", aerialway)
		way:Attribute("name", node:Find("name"))
	end
end
