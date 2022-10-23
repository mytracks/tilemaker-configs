-- nodes to be processed
node_keys = { "highway" }

-- node attributes to be copied
node_attributes = { "name" }


-- Implement Sets in tables
function Set(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

function init_function()
end

function exit_function()
end

function TrySetAttribute(obj, source, target)
	local value = obj:Find(source)
	if value~="" then
		obj:Attribute(target, value)
	end
end

majorRoadValues = Set { "motorway", "trunk", "primary" }
mainRoadValues  = Set { "secondary", "motorway_link", "trunk_link", "primary_link", "secondary_link" }
midRoadValues   = Set { "tertiary", "tertiary_link" }
minorRoadValues = Set { "unclassified", "residential", "road", "living_street" }
trackValues     = Set { "cycleway", "byway", "bridleway", "track" }
pathValues      = Set { "footway", "path", "steps", "pedestrian" }
linkValues      = Set { "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link" }
constructionValues = Set { "primary", "secondary", "tertiary", "motorway", "service", "trunk", "track" }

function node_function(node)
	node:Layer("transportation", false)
	node:Attribute("class", "highway")

	-- copy attributes
	for _,attr in pairs(node_attributes) do
		TrySetAttribute(node, attr, attr)
	end
end

function way_function(way)
	local highway = way:Find("highway")

	if highway~="" then
		local access = way:Find("access")
		if access=="private" or access=="no" then return end

		local h = highway
		local minzoom = 99
		local layer = "transportation"
		-- if majorRoadValues[highway] then              minzoom = 4 end
		-- if highway == "trunk"       then              minzoom = 5
		-- elseif highway == "primary" then              minzoom = 7 end
		-- if mainRoadValues[highway]  then              minzoom = 9 end
		if midRoadValues[highway]   then              minzoom = 11 end
		if minorRoadValues[highway] then h = "minor"; minzoom = 11 end
		if trackValues[highway]     then h = "track"; minzoom = 11 end
		if pathValues[highway]      then h = "path" ; minzoom = 11 end
		if h=="service"             then              minzoom = 11 end

		-- Links (ramp)
		local ramp=false
		if linkValues[highway] then
			splitHighway = split(highway, "_")
			highway = splitHighway[1]; h = highway
			ramp = true
			minzoom = 11
		end

		-- Construction
		if highway == "construction" then
			if constructionValues[construction] then
				h = construction .. "_construction"
				if construction ~= "service" and construction ~= "track" then
					minzoom = 11
				else
					minzoom = 12
				end
			else
				h = "minor_construction"
				minzoom = 14
			end
		end

		-- Write to layer
		if minzoom <= 14 then
			way:Layer(layer, false)
			way:MinZoom(minzoom)
			SetZOrder(way)
			way:Attribute("class", h)
			SetBrunnelAttributes(way)
			if ramp then way:AttributeNumeric("ramp",1) end

			-- Service
			if highway == "service" and service ~="" then way:Attribute("service", service) end

			local oneway = way:Find("oneway")
			if oneway == "yes" or oneway == "1" then
				way:AttributeNumeric("oneway",1)
			end
			if oneway == "-1" then
				-- **** TODO
			end

			-- Write names
			if minzoom < 8 then
				minzoom = 8
			end
			way:Layer("transportation_name", false)
			way:MinZoom(minzoom)

			SetNameAttributes(way)
			way:Attribute("class",h)
			way:Attribute("network","road") -- **** could also be us-interstate, us-highway, us-state
			if h~=highway then way:Attribute("subclass",highway) end
			local ref = way:Find("ref")
			if ref~="" then
				way:Attribute("ref",ref)
				way:AttributeNumeric("ref_length",ref:len())
			end
		end
	end
end

function SetZOrder(way)
	local highway = way:Find("highway")
	local layer = tonumber(way:Find("layer"))
	local bridge = way:Find("bridge")
	local tunnel = way:Find("tunnel")
	local zOrder = 0
	if bridge ~= "" and bridge ~= "no" then
		zOrder = zOrder + 10
	elseif tunnel ~= "" and tunnel ~= "no" then
		zOrder = zOrder - 10
	end
	if not (layer == nil) then
		if layer > 7 then
			layer = 7
		elseif layer < -7 then
			layer = -7
		end
		zOrder = zOrder + layer * 10
	end
	local hwClass = 0
	-- See https://github.com/omniscale/imposm3/blob/53bb80726ca9456e4a0857b38803f9ccfe8e33fd/mapping/columns.go#L251
	if highway == "motorway" then
		hwClass = 9
	elseif highway == "trunk" then
		hwClass = 8
	elseif highway == "primary" then
		hwClass = 6
	elseif highway == "secondary" then
		hwClass = 5
	elseif highway == "tertiary" then
		hwClass = 4
	else
		hwClass = 3
	end
	zOrder = zOrder + hwClass
	way:ZOrder(zOrder)
end

function SetBrunnelAttributes(obj)
	if     obj:Find("bridge") == "yes" then obj:Attribute("brunnel", "bridge")
	elseif obj:Find("tunnel") == "yes" then obj:Attribute("brunnel", "tunnel")
	elseif obj:Find("ford")   == "yes" then obj:Attribute("brunnel", "ford")
	end
end

function SetNameAttributes(obj)
	local name = obj:Find("name"), iname
	local main_written = name
	-- if we have a preferred language, then write that (if available), and additionally write the base name tag
	if preferred_language and obj:Holds("name:"..preferred_language) then
		iname = obj:Find("name:"..preferred_language)
		obj:Attribute(preferred_language_attribute, iname)
		if iname~=name and default_language_attribute then
			obj:Attribute(default_language_attribute, name)
		else main_written = iname end
	else
		obj:Attribute(preferred_language_attribute, name)
	end
	-- then set any additional languages
	for i,lang in ipairs(additional_languages) do
		iname = obj:Find("name:"..lang)
		if iname=="" then iname=name end
		if iname~=main_written then obj:Attribute("name:"..lang, iname) end
	end
end
