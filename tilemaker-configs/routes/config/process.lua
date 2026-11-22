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
-- routes route planning prefers. Mountain bike routes mostly use the cycling levels.
network_levels = {
	iwn = 4, icn = 4,
	nwn = 3, ncn = 3,
	rwn = 2, rcn = 2,
	lwn = 1, lcn = 1
}
level_names = { "local", "regional", "national", "international" }

-- Route planning takes route=foot for a hiking route, so the map does too.
function RouteKind(route)
	if route=="foot" then return "hiking" end
	return route
end

-- A cycle, hiking or MTB route counts only with a network level: one without, such as a basic cycle
-- network's relation, is not a route route planning prefers, and the map shows what it prefers.
leveled_kinds = { bicycle = true, hiking = true, mtb = true }

function IsRouteWithoutLevel(kind, network)
	return leveled_kinds[kind]==true and network_levels[network]==nil
end

-- The legacy app reads the attributes per ref and the aggregated ones of the kinds it knew. It
-- knows no hiking and MTB routes, so these do without them, which keeps the tiles smaller.
kinds_without_legacy_attributes = { hiking = true, mtb = true }

-- The kinds that the myTracks app can select on the map; those of public transport are grouped to
-- lines.
selectable_kinds = { bicycle = true, hiking = true, mtb = true, bus = true, tram = true, subway = true }
public_transport_kinds = { bus = true, tram = true, subway = true }

-- A value inside a record must not contain the separators of fields and records.
function RecordField(value)
	return (string.gsub(value, "[\t\r\n]", " "))
end

-- One route of a way as a record of <kind>_lines, see the README. It is one attribute per kind and
-- not one per relation, because tilemaker lists every attribute key in the set's metadata, which
-- each client loads.
function RouteRecord(id, kind, ref, name, operator, network)
	ref, name, operator, network = RecordField(ref), RecordField(name), RecordField(operator), RecordField(network)
	local key = ""
	-- Each direction and variant of a public transport line is a relation of its own, so a line
	-- is recognized by ref, operator and network. Without the latter two, lines of different towns
	-- would look alike, so then there is only the id.
	if public_transport_kinds[kind] and ref~="" and (operator~="" or network~="") then
		key = "#"..ref.."|"..operator.."|"..network
	end
	return table.concat({ string.format("%d", id), key, ref, name, operator, network }, "\t")
end

-- The records by ascending id, so that ways on the same routes get the same value and can merge.
function JoinedRecords(records)
	local ids = {}
	for id,_ in pairs(records) do
		table.insert(ids, id)
	end
	table.sort(ids)

	local lines = {}
	for _,id in ipairs(ids) do
		table.insert(lines, records[id])
	end
	return "\n"..table.concat(lines, "\n").."\n"
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

-- highway=stop is a stop sign. Its class "stop" would be drawn with the symbol of railway=stop, and
-- the ways of hiking and MTB routes bring many of them into the extract.
function IsStopSign(node)
	return node:Find("highway")=="stop" and node:Find("railway")==""
end

function node_function(node)
	-- check whether highway or railway tag exists
	local obj_type, obj = FindTag(node, {"highway", "railway"})
	if obj_type~=nil and not IsStopSign(node) then
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
		local levels = {} -- the highest network level per kind that needs one
		local records = {} -- per selectable kind, the records of the way's routes by relation id
		while true do
			local rel = way:NextRelation()
			if not rel then break end

			-- read the type of route, such as 'bicycle'
			local route = RouteKind(way:FindInRelation("route"))
			local network = way:FindInRelation("network")

			-- relation_scan_function accepts no such route without a level, but a relation
			-- accepted for another route type may still carry one of these kinds in theory
			if route~="" and not IsRouteWithoutLevel(route, network) then
				way:Attribute(route.."_route", "yes")

				if leveled_kinds[route] then
					local level = network_levels[network]
					if level > (levels[route] or 0) then
						levels[route] = level
					end
				end

				local ref = way:FindInRelation("ref")

				if selectable_kinds[route] then
					records[route] = records[route] or {}
					-- by id, as a way can be a member of the same relation twice
					records[route][rel] = RouteRecord(rel, route, ref, way:FindInRelation("name"), way:FindInRelation("operator"), network)
				end

				local has_legacy_attributes = not kinds_without_legacy_attributes[route]

				if has_legacy_attributes and ref~="" then
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

				if has_legacy_attributes then
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
		end

		for kind,level in pairs(levels) do
			way:Attribute(kind.."_route_level", level_names[level])
		end

		for kind,kind_records in pairs(records) do
			way:Attribute(kind.."_lines", JoinedRecords(kind_records))
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
		local route = RouteKind(relation:Find("route"))

		if leveled_kinds[route] then
			-- accept cycle, hiking and MTB routes with a network level, with or without a ref, as
			-- the openmaptiles build does for route planning
			if not IsRouteWithoutLevel(route, relation:Find("network")) then
				relation:Accept()
			end
		elseif relation:Find("ref")~="" then
			-- accept all other routes with a ref number
			relation:Accept()
		end
	end
end
