node_keys = { "piste:type", "aerialway" }

function init_function()
end

function exit_function()
end

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
	local piste = node:Find("piste:type")
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

function way_function(way)
	local piste = way:Find("piste:type")
	if piste~="" then
		way:Layer("piste", false)
		way:Attribute("class", piste)
		TrySetAttribute(way, "name")
		TrySetAttribute(way, "area")
		TrySetAttribute(way, "landuse")
		TrySetPisteAttribute(way, "grooming")
		TrySetPisteAttribute(way, "ref")
		TrySetPisteAttribute(way, "difficulty")
	end

	local aerialway = way:Find("aerialway")
	if aerialway~="" then
		way:Layer("aerialway", false)
		way:Attribute("class", aerialway)
		way:Attribute("name", way:Find("name"))
	end
end
