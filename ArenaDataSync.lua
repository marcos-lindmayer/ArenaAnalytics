local _, ArenaAnalytics = ... -- Namespace
ArenaAnalytics.DataSync = {}

local DataSync = ArenaAnalytics.DataSync;

local skipDataSync = true;

function DataSync:requestMissingData(currentArena)
    if skipDataSync then return end;

    if (currentArena["gotAllArenaInfo"] == false) then 
		-- print("Missing specs. Requesting data")
		if(IsInInstance() or IsInGroup(1)) then
			local messageChannel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";

			-- Request party specs
			for i = 1, #currentArena["party"] do
				if (#currentArena["party"][i]["spec"]<3) then
					local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_request|spec#" .. currentArena["party"][i]["name"], messageChannel)
				end
			end

			-- Request enemy specs
			for j = 1, #currentArena["enemy"] do
				if (#currentArena["enemy"][j]["spec"]<3) then
					local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_request|spec#" .. currentArena["enemy"][j]["name"], messageChannel)
				end
			end
		end
	end
end

-- Handles both requests and delivers for specs, enemy MMR/Rating, and version
function DataSync:handleSync(...)
	if skipDataSync then return end;

	local _, msg = ...	

	if(msg == nil) then
		ArenaAnalytics:Print("WARNING: handleSync called with nil message.");
		return;
	end

	-- Exit out if expected symbols for sync message format is missing
	if (not string.find(msg, "|") or not string.find(msg, "_") or not string.find(msg, "%#")) then 
		return;
	end

	local indexOfSeparator, _ = string.find(msg, "_")
	local  sender = msg:sub(1, indexOfSeparator - 1);
	-- Only read if you're not the sender
	if (sender ~= tostring(UnitGUID("player"))) then
		local msgString = msg:sub(indexOfSeparator + 1, #msg);
		indexOfSeparator, _ = string.find(msgString, "|")
		local messageType = msgString:sub(1, indexOfSeparator - 1);
		local messageData = msgString:sub(indexOfSeparator + 1, #msgString);
		indexOfSeparator, _ = string.find(messageData, "#")
		local dataType = messageData:sub(1, indexOfSeparator - 1);
		local dataValue = messageData:sub(indexOfSeparator + 1, #messageData);
		ArenaAnalytics:Print("|cff00cc66" .. sender .. "|r " .. messageType .. "ed: " .. messageData)
		if (messageType == "request") then
			if (dataType == "spec") then
				-- Check if arena in progress, else need to get data from saved game
				local foundSpec = false;
				local spec
				if (currentArena["mapId"] ~= nil) then
					for i = 1, #arenaParty do
						if (arenaParty[i]["name"] == dataValue and #arenaParty[i]["spec"]>2) then
							foundSpec = true;
							spec = arenaParty[i]["spec"]
							break;
						end
					end
					if (foundSpec == false) then
						for i = 1, #arenaEnemy do
							if (arenaEnemy[i]["name"] == dataValue and #arenaEnemy[i]["spec"]>2) then
								spec = arenaEnemy[i]["spec"]
								foundSpec = true
								break;
							end
						end
					end
					
				else
					local lastGamePerBracket = {
						#ArenaAnalyticsDB["2v2"] > 0 and ArenaAnalyticsDB["2v2"][#ArenaAnalyticsDB["2v2"]] or 0,
						#ArenaAnalyticsDB["3v3"] > 0 and ArenaAnalyticsDB["3v3"][#ArenaAnalyticsDB["3v3"]] or 0,
						#ArenaAnalyticsDB["5v5"] > 0 and ArenaAnalyticsDB["5v5"][#ArenaAnalyticsDB["5v5"]] or 0,
					}
					table.sort(lastGamePerBracket, function (k1,k2)
						if (k1["dateInt"] and k2["dateInt"]) then
							return k1["dateInt"] < k2["dateInt"];
						end
					end)
					local lastGame = lastGamePerBracket[3]

					if (lastGame["team"]) then 
						for i = 1, #lastGame["team"] do
							if (lastGame["team"][i]["name"] == dataValue and #lastGame["team"][i]["spec"] > 2) then
								foundSpec = true;
								spec = lastGame["team"][i]["spec"];
								break;
							end
						end
						if (lastGame["enemyTeam"]) then 
							for j = 1, #lastGame["enemyTeam"] do
								if (lastGame["enemyTeam"][j]["name"] == dataValue and #lastGame["enemyTeam"][j]["spec"] > 2) then
									foundSpec = true;
									spec = lastGame["enemyTeam"][j]["spec"];
									break;
								end
							end
						end
					end
				end
				
				if (foundSpec) then
					if (IsInInstance() or IsInGroup(1)) then
						local messageChannel = IsInInstance() and "INSTANCE_CHAT" or "PARTY";
						local messageSuccess = C_ChatInfo.SendAddonMessage("ArenaAnalytics", UnitGUID("player") .. "_deliver|spec#" .. sender .. "?" .. dataValue .. "=" .. spec, messageChannel);
					end
				end
			elseif (dataType == "enemyRateMMR") then

			end
		elseif (messageType == "deliver") then
			if (dataType == "spec") then
				
				if (currentArena["pendingSync"]) then
					print("sending data")
					indexOfSeparator, _ = string.find(dataValue, "?")
					local nameAndSpec = dataValue:sub(indexOfSeparator + 1, #dataValue);
					indexOfSeparator, _ = string.find(nameAndSpec, "=")
					local deliveredName = nameAndSpec:sub(1, indexOfSeparator - 1);
					local deliveredSpec = nameAndSpec:sub(indexOfSeparator + 1, #nameAndSpec);
					local lastGame
					local lastGamePerBracket = {
						#ArenaAnalyticsDB["2v2"] > 0 and ArenaAnalyticsDB["2v2"][#ArenaAnalyticsDB["2v2"]] or 0,
						#ArenaAnalyticsDB["3v3"] > 0 and ArenaAnalyticsDB["3v3"][#ArenaAnalyticsDB["3v3"]] or 0,
						#ArenaAnalyticsDB["5v5"] > 0 and ArenaAnalyticsDB["5v5"][#ArenaAnalyticsDB["5v5"]] or 0,
					}
					
					table.sort(lastGamePerBracket, function (k1,k2)
						if (k1["dateInt"] and k2["dateInt"]) then
							return k1["dateInt"] < k2["dateInt"];
						end
					end)
					local lastGame = lastGamePerBracket[3]
					
					local foundName = false;

					if (lastGame["team"]) then 
						for i = 1, #lastGame["team"] do
							if (lastGame["team"][i]["name"] == deliveredName and #lastGame["team"][i]["spec"] < 2) then
								foundName = true;
								lastGame["team"][i]["spec"] = deliveredSpec
								break;
							end
						end
						if (lastGame["enemyTeam"]) then 
						for j = 1, #lastGame["enemyTeam"] do
								if (lastGame["enemyTeam"][j]["name"] == deliveredName and #lastGame["enemyTeam"][j]["spec"] < 2) then
									foundName = true;
									lastGame["team"][j]["spec"] = deliveredSpec
									break;
								end
							end
						end
					end
					if (foundName) then
						ArenaAnalytics:Print("Spec(" .. deliveredSpec .. ") for " .. deliveredName .. " has been added!")
					else
						ArenaAnalytics:Print("Error! Name could not be found or already has a spec assigned for latest match!")
					end
				else
					currentArena["pendingSync"] = true;
					currentArena["pendingSyncData"] = ...;
					print("data got requested to me, storing and sending when arena is over for me")
				end
				
			elseif (dataType == "version") then
				indexOfSeparator, _ = string.find(dataValue, "=")
				local version = GetAddOnMetadata("ArenaAnalytics", "Version") or 9999;
				local deliveredVersion = dataValue:sub(indexOfSeparator + 1, #dataValue);
				deliveredVersion = deliveredVersion:gsub("%.","")
				version = version:gsub("%.","")
				print(tonumber(deliveredVersion), tonumber(version))
				if (tonumber(deliveredVersion) > tonumber(version)) then
					ArenaAnalytics:Print("There is an update available. Please download the latest release from TBD") --TODO: Add curseforge page
				end
			end
		end
	end
end
