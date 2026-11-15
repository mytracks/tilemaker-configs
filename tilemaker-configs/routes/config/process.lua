-- nodes to be processed
node_keys = { "highway", "railway" }

-- node attributes to be copied
node_attributes = { "name", "bicycle", "foot", "access", "smoothness", "surface", "type", "bridge", "tunnel", "route", "network", "cycle_network", "roundtrip", "icn_ref", "lcn_ref", "rcn_ref", "ncn_ref" }

-- way attributes to be copied
way_attributes = { "name", "bicycle", "foot", "access", "smoothness", "surface", "type", "bridge", "tunnel" }

-- route attributes to be copied
route_attributes = { "name", "colour", "operator", "lcn", "lcn_ref", "icn", "icn_ref", "rcn", "rcn_ref", "ncn", "ncn_ref", "ref" }

-- Network levels of marked routes, as the openmaptiles build ranks them for routing in the myTracks
-- app (`MarkedRoute` in planetiler-openmaptiles' Transportation.java), so that the map shows the
-- cycle routes route planning prefers. Mountain bike routes mostly use the cycling levels.
network_levels = {
	iwn = 4, icn = 4,
	nwn = 3, ncn = 3,
	rwn = 2, rcn = 2,
	lwn = 1, lcn = 1
}
level_names = { "local", "regional", "national", "international" }

-- A cycle route counts only with a network level: one without, such as a basic cycle network's
-- relation, is not a route route planning prefers, and the map shows what route planning prefers.
function IsCycleRouteWithoutLevel(route, network)
	return route=="bicycle" and network_levels[network]==nil
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

function FindTag(obj, tags)
	for _,tag in pairs(tags) do
		local value = obj:Find(tag)
		if value~="" then
			return tag, value
		end
	end

	return nil, nil
end

function node_function(node)
	-- check whether highway or railway tag exists
	local obj_type, obj = FindTag(node, {"highway", "railway"})
	if obj_type~=nil then
		node:Layer("route", false)
		node:Attribute("obj_type", obj_type)
		node:Attribute("class", obj)

		-- copy attributes
		for _,attr in pairs(node_attributes) do
			TrySetAttribute(node, attr, attr)
		end
	end
end

function sorted_attributes(attributes_table)
	local tkeys = {}
	for k,_ in pairs(attributes_table) do 
		table.insert(tkeys, k) 
	end
	table.sort(tkeys)
	return pairs(tkeys)
end

function way_function(way)
	-- check whether highway or railway tag exists
	local obj_type, obj = FindTag(way, {"highway", "railway"})
	if obj_type~=nil then
		way:Layer("route", false)
		way:Attribute(obj_type.."_class", obj)

		-- copy attributes
		for _,attr in pairs(way_attributes) do
			TrySetAttribute(way, attr, obj_type.."_"..attr)
		end

		-- iterate of relations in order to copy attributes
		local attributes = {} -- dictionary with attributes from all relations
		local bicycle_level = 0 -- the highest network level among the way's cycle routes
		while true do
			local rel = way:NextRelation()
			if not rel then break end

			-- read the type of route, such as 'bicycle'
			local route = way:FindInRelation("route")

			-- relation_scan_function accepts no cycle route without a level, but a relation
			-- accepted for another route type may still carry route=bicycle in theory
			if route~="" and not IsCycleRouteWithoutLevel(route, way:FindInRelation("network")) then
				way:Attribute(route.."_route", "yes")

				if route=="bicycle" then
					local level = network_levels[way:FindInRelation("network")]
					if level > bicycle_level then
						bicycle_level = level
					end
				end

				local ref = way:FindInRelation("ref")

				if ref~="" then
					local operator = way:FindInRelation("operator")
					if operator~="" then
						way:Attribute(route.."_route_operator_"..ref, operator)
					else
						way:Attribute(route.."_route_operator_"..ref, "__unknown__")
					end

					local name = way:FindInRelation("name")
					if name~="" then
						way:Attribute(route.."_route_name_"..ref, name)
					end
				end

				-- copy attributes from relations to the dictionary 
				for _,attr in pairs(route_attributes) do
					local way_name = route.."_"..attr
					local value = way:FindInRelation(attr)

					if attributes[way_name] ~= nil then
						attributes[way_name][value] = true
					else
						attributes[way_name] = { [value] = true }
					end
				end		
			end
		end

		if bicycle_level > 0 then
			way:Attribute("bicycle_route_level", level_names[bicycle_level])
		end

		-- copy attributes from dictionary to the way object
		for attr,value_table in pairs(attributes) do
			if value_table ~= nil then
				local string_value = ""

				for _,value in sorted_attributes(value_table) do
					if string_value=="" then
						string_value = value
					else
						string_value = string_value..";"..value
					end
				end

				way:Attribute(attr, string_value)
			end
		end
	end
end

function relation_scan_function(relation)
	if relation:Find("type")=="route" then
		local route = relation:Find("route")

		if route=="bicycle" then
			-- accept cycle routes with a network level, with or without a ref, as the
			-- openmaptiles build does for route planning
			if not IsCycleRouteWithoutLevel(route, relation:Find("network")) then
				relation:Accept()
			end
		elseif relation:Find("ref")~="" then
			-- accept all other routes with a ref number
			relation:Accept()
		end
	end
end
