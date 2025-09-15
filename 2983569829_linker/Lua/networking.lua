network = {}


-- Shared Side Start --

local function ConvertStringToRequiredItems(value)
	local relatedItemClass = LuaUserData.CreateStatic("Barotrauma.RelatedItem")
	local requiredItems = {}
	
	for requiredItemXml in value:gmatch("<[^>]+/>") do
		local xml = XDocument.Parse(requiredItemXml).Root
		local contentXml = ContentXElement(nil, xml)
		local relatedItem = relatedItemClass.__new(contentXml, "LuaEditorRequiredItem")
		local requiredType = relatedItem.Type
		
		if requiredItems[requiredType] == nil then
			requiredItems[requiredType] = {relatedItem}
		else
			table.insert(requiredItems[requiredType], relatedItem)
		end
	end
	
	return requiredItems
end

-- Shared Side End --
-- Client Side Start --

if CLIENT then

local function ConvertToString(value)
    return tostring(value)
end

local function ConvertColorToString(value)
    if type(value) == "userdata" then
        return string.format("%f,%f,%f,%f", value.r, value.g, value.b, value.a)
    else
        print("failed to convert color")
    end
end

local function ConvertRequiredItemsToString(value)
    if type(value) == "table" then
		local requiredItemsXMLs = " "
		for requiredType, requiredTypeItems in pairs(value) do
			for i, requiredItem in ipairs(requiredTypeItems) do
				local requiredItemsXML = XElement("requireditem")
				requiredItem.Save(requiredItemsXML)
				
				requiredItemsXMLs = requiredItemsXMLs .. tostring(requiredItemsXML)
			end
		end
		return requiredItemsXMLs
    else
        print("failed to convert RequiredItems to string")
    end
end

Update = {
	itemupdatevalue = {
		{"String", "String", "Number", "Number2"},  -- Three parameters: ItemString, ActionString, Value
		fn = function(ItemString, ActionString, Value, Value2)
			if Value2 == "Color" then
				itemupdatestring = ItemString .. "|" .. ActionString .. "|" .. ConvertColorToString(Value) .. "|" .. Value2
			elseif Value2 == "RequiredItems" then
				itemupdatestring = ItemString .. "|" .. ActionString .. "|" .. ConvertRequiredItemsToString(Value) .. "|" .. Value2
			else
				if Value2 then
					itemupdatestring = ItemString .. "|" .. ActionString .. "|" .. ConvertToString(Value) .. "|" .. ConvertToString(Value2)
				else
					itemupdatestring = ItemString .. "|" .. ActionString .. "|" .. ConvertToString(Value)
				end
			end
			local itemupdatenetwork = Networking.Start("itemupdatenetworking")
				itemupdatenetwork.WriteString(itemupdatestring)
			Networking.Send(itemupdatenetwork)
		end
	}
}

Networking.Receive("settingsnetworking", function (settingsnetwork)
    local receivedData = settingsnetwork.ReadString()  -- Get the received string
    -- Deserialize the received string into a Lua table
    local Settings = {}
    for key, value in string.gmatch(receivedData, '([^;]+)=([^;]+)') do
        if value == "true" then
            Settings[key] = true
        elseif value == "false" then
            Settings[key] = false
        else
            Settings[key] = tonumber(value) or value
        end
    end

    -- Update your local settings with the received data
    EditGUI.Settings = Settings
end)


	EditGUI.networkstart = function()
		if Game.IsMultiplayer and settings == false or settings == nil then
			EditGUI.AddMessage("Applied settings to " .. itemedit.Name, owner)
		else
			if settings == true then
				File.Write(EditGUI.Path .. "/clientsidesettings.json", json.serialize(EditGUI.ClientsideSettings))
				if Game.IsMultiplayer then

					local serializedData = ""
					for key, value in pairs(EditGUI.Settings) do
						if type(value) == "boolean" then
							value = tostring(value)
						end
						serializedData = serializedData .. key .. "=" .. tostring(value) .. ";"
					end
					local settingsnetwork = Networking.Start("settingsnetworkupdate")
						settingsnetwork.WriteString(serializedData)
					Networking.Send(settingsnetwork)
				else
					File.Write(EditGUI.Path .. "/settings.json", json.serialize(EditGUI.Settings))
				end
				EditGUI.AddMessage("Saved Changes", owner)
			else
				if itemedit == nil then
					return
				end
			EditGUI.AddMessage("Apply unnecessary in singleplayer", owner)
			end
		end
	end
	
	
end

-- Client Side End --
-- Server Side Start

if SERVER then 

EditGUI.Settings = json.parse(File.Read(EditGUI.Path .. "/settings.json"))

local function split(str, separator)
    if str == nil then
        return {} -- Return an empty table for an empty string
    end
    local result = {}
    local pattern = string.format("([^%s]+)", separator)
    str:gsub(pattern, function(c) result[#result + 1] = c end)
    return result
end

function removePeriodsAndNumbers(inputString)
    local stringWithoutPeriodsAndNumbers = string.gsub(inputString, "[%.%d]", "")
    return stringWithoutPeriodsAndNumbers
end

Networking.Receive("itemupdatenetworking", function (itemupdatenetwork,sender)
	if EditGUI.Settings.permissionsetting == 0 then
		if sender.Permissions == 0 then
			return
		end
	else
		if not sender.HasPermission(ClientPermissions[EditGUI.Settings.permissionsetting]) then
			return
		end
	end
	itemupdatestring = itemupdatenetwork.ReadString()
    local values = split(itemupdatestring, "|")
    local ItemString = values[1]
    local ActionString = values[2]
    local ValueString = values[3]
	if values[4] then 
		ValueString2 = values[4]
	else
		ValueString2 = nil
	end
    -- Perform the logic on the server
    local itemedit = Entity.FindEntityByID(tonumber(ItemString))
	local Value = nil
    if ValueString == "true" then
        Value = true
    elseif ValueString == "false" then
        Value = false
    elseif ValueString2 == "Color" then
        local colorValues = split(ValueString , ",")
        if #colorValues == 4 then
            Value = Color(tonumber(colorValues[1]), tonumber(colorValues[2]), tonumber(colorValues[3]), tonumber(colorValues[4]))
		end
	elseif ValueString2 == "RequiredItems" then
		Value = ConvertStringToRequiredItems(ValueString)
	else
		Value = tonumber(ValueString) or ValueString
    end
	local mainAction, subAction = ActionString:match("(.-)%.([^%.]+)$")
	local valueStringOutput = ValueString or "nil"
	if mainAction and subAction then
		local key = tonumber(mainAction) 
		itemedit.Components[key][subAction] = Value
		print(sender.Name .. " edited '" .. itemedit.Name .. "' " .. removePeriodsAndNumbers(ActionString) .. " to " .. valueStringOutput)
	elseif ActionString == "Move" then
		Value2 = tonumber(ValueString2) or ValueString2 
		itemedit.Move(Vector2(Value, Value2), false)
		print(sender.Name .. " moved '" .. itemedit.Name .. "' by x" .. valueStringOutput .. " And y" .. ValueString2)
	else
		itemedit[ActionString] = Value
		print(sender.Name .. " edited '" .. itemedit.Name .. "' " .. removePeriodsAndNumbers(ActionString) .. " to " .. valueStringOutput)
	end
	local itemupdatetoclient = Networking.Start("itemupdatetoclients")
		itemupdatetoclient.WriteString(itemupdatestring)
	Networking.Send(itemupdatetoclient)
end)



Networking.Receive("serversettingsstart", function ()

    if not File.Exists(EditGUI.Path .. "/settings.json") then
        File.Write(EditGUI.Path .. "/settings.json", json.serialize(dofile(EditGUI.Path .. "/Lua/defaultsettings.lua")))
    end
    -- Load the settings from file
    local Settings = json.parse(File.Read(EditGUI.Path .. "/settings.json"))
    -- Serialize the settings table into a string
    local serializedData = ""
    for key, value in pairs(Settings) do
        serializedData = serializedData .. key .. "=" .. tostring(value) .. ";"
    end

    -- Send the serialized settings data over the network
    local settingsnetwork = Networking.Start("settingsnetworking")
		settingsnetwork.WriteString(serializedData)
    Networking.Send(settingsnetwork)
end)



Networking.Receive("settingsnetworkupdate", function (settingsnetwork,sender)
	if not sender.HasPermission(ClientPermissions.All) then
		return
	end
    local receivedData = settingsnetwork.ReadString()
    local Settingsupdate = {}
    for key, value in string.gmatch(receivedData, '([^;]+)=([^;]+)') do
        if value == "true" then
            Settingsupdate[key] = true
        elseif value == "false" then
            Settingsupdate[key] = false
        else
            Settingsupdate[key] = tonumber(value) or value
        end
    end
	File.Write(EditGUI.Path .. "/settings.json", json.serialize(Settingsupdate))
    -- Load the settings from file
    local Settings = json.parse(File.Read(EditGUI.Path .. "/settings.json"))
    -- Serialize the settings table into a string
    local serializedData = ""
    for key, value in pairs(Settings) do
        serializedData = serializedData .. key .. "=" .. tostring(value) .. ";"
    end

    -- Send the serialized settings data over the network
    local settingsnetwork = Networking.Start("settingsnetworking")
		settingsnetwork.WriteString(serializedData)
    Networking.Send(settingsnetwork)
end)

Networking.Receive("servermsgstart", function (itemeditnetwork,sender)
	if EditGUI.Settings.permissionsetting == 0 then
		if sender.Permissions == 0 then
			return
		end
	else
		if not sender.HasPermission(ClientPermissions[EditGUI.Settings.permissionsetting]) then
			return
		end
	end
    local itemedit = Entity.FindEntityByID(itemeditnetwork.ReadUInt16())
	itemedit.SpriteDepth = itemeditnetwork.ReadSingle()
	itemedit.Rotation = itemeditnetwork.ReadSingle()
	itemedit.Scale = itemeditnetwork.ReadSingle()
	itemedit.Condition = itemeditnetwork.ReadSingle()
	itemedit.Tags = itemeditnetwork.ReadString()
	itemedit.NonInteractable = itemeditnetwork.ReadBoolean()
	itemedit.NonPlayerTeamInteractable = itemeditnetwork.ReadBoolean()
	itemedit.InvulnerableToDamage = itemeditnetwork.ReadBoolean()
	itemedit.DisplaySideBySideWhenLinked = itemeditnetwork.ReadBoolean()
	itemedit.HiddenInGame = itemeditnetwork.ReadBoolean()	
	
	
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("SpriteDepth")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("Rotation")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("Scale")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("Condition")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("Tags")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("NonInteractable")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("NonPlayerTeamInteractable")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("InvulnerableToDamage")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("DisplaySideBySideWhenLinked")], itemedit))
		Networking.CreateEntityEvent(itemedit, Item.ChangePropertyEventData(itemedit.SerializableProperties[Identifier("HiddenInGame")], itemedit))
end)

Networking.Receive("flipxnetwork", function (mirrorx,sender)
	if EditGUI.Settings.permissionsetting == 0 then
		if sender.Permissions == 0 then
			return
		end
	else
		if not sender.HasPermission(ClientPermissions[EditGUI.Settings.permissionsetting]) then
			return
		end
	end
    local itemedit = Entity.FindEntityByID(mirrorx.ReadUInt16())
	if itemedit then
		itemedit.FlipX(false)
		print(sender.Name .. " MirroredX '" .. itemedit.Name .. "'")
		
		local flipx = Networking.Start("flipxclientnetwork")
			flipx.WriteUInt16(UShort(itemedit.ID))
		Networking.Send(flipx)
	end
end)

	Networking.Receive("flipynetwork", function (mirrory,sender)
	if EditGUI.Settings.permissionsetting == 0 then
		if sender.Permissions == 0 then
			return
		end
	else
		if not sender.HasPermission(ClientPermissions[EditGUI.Settings.permissionsetting]) then
			return
		end
	end
        local itemedit = Entity.FindEntityByID(mirrory.ReadUInt16())
		
		if itemedit then
			itemedit.FlipY(false)
			print(sender.Name .. " MirroredY '" .. itemedit.Name .. "'")
		
			local flipy = Networking.Start("flipyclientnetwork")
				flipy.WriteUInt16(UShort(itemedit.ID))
			Networking.Send(flipy)
		end
		
	end)
	
	
	Networking.Receive("linkremove", function (msg,sender)
	if EditGUI.Settings.permissionsetting == 0 then
		if sender.Permissions == 0 then
			return
		end
	else
		if not sender.HasPermission(ClientPermissions[EditGUI.Settings.permissionsetting]) then
			return
		end
	end

        local itemedit1 = Entity.FindEntityByID(msg.ReadUInt16())
        local itemedit2 = Entity.FindEntityByID(msg.ReadUInt16())
        LinkRemove(itemedit1, itemedit2)
		print(sender.Name .. " unlinked '" .. itemedit1.Name .. "' and '" .. itemedit2.Name .. "'")

		local msg = Networking.Start("lualinker.remove")
			msg.WriteUInt16(UShort(itemedit1.ID))
			msg.WriteUInt16(UShort(itemedit2.ID))
		Networking.Send(msg)
	end)

	Networking.Receive("linkadd", function (msg,sender)
	if EditGUI.Settings.permissionsetting == 0 then
		if sender.Permissions == 0 then
			return
		end
	else
		if not sender.HasPermission(ClientPermissions[EditGUI.Settings.permissionsetting]) then
			return
		end
	end

        local itemedit1 = Entity.FindEntityByID(msg.ReadUInt16())
        local itemedit2 = Entity.FindEntityByID(msg.ReadUInt16())
        LinkAdd(itemedit1, itemedit2)
		print(sender.Name .. " linked '" .. itemedit1.Name .. "' and '" .. itemedit2.Name .. "'")
		
		local msg = Networking.Start("lualinker.add")
			msg.WriteUInt16(UShort(itemedit1.ID))
			msg.WriteUInt16(UShort(itemedit2.ID))
		Networking.Send(msg)

	end)


end

-- Server Side End --
-- Client Side Start --

if CLIENT and Game.IsMultiplayer then

	local function split(str, separator)
		if str == nil then
			return {} -- Return an empty table for an empty string
		end
		local result = {}
		local pattern = string.format("([^%s]+)", separator)
		str:gsub(pattern, function(c) result[#result + 1] = c end)
		return result
	end

	Networking.Receive("itemupdatetoclients", function (itemupdatetoclient)
		itemupdatestring = itemupdatetoclient.ReadString()
		local values = split(itemupdatestring, "|")
		local ItemString = values[1]
		local ActionString = values[2]
		local ValueString = values[3]
		if values[4] then 
			ValueString2 = values[4]
		else
			ValueString2 = nil
		end
		-- Perform the logic on the server
		local itemedit = Entity.FindEntityByID(tonumber(ItemString))
		local Value = nil
		if ValueString == "true" then
			Value = true
		elseif ValueString == "false" then
			Value = false
		elseif ValueString2 == "Color" then
			local colorValues = split(ValueString , ",")
			if #colorValues == 4 then
				Value = Color(tonumber(colorValues[1]), tonumber(colorValues[2]), tonumber(colorValues[3]), tonumber(colorValues[4]))
			end
		elseif ValueString2 == "RequiredItems" then
			Value = ConvertStringToRequiredItems(ValueString)
		else
			Value = tonumber(ValueString) or ValueString 
		end
		local mainAction, subAction = ActionString:match("(.-)%.([^%.]+)$")
		if mainAction and subAction then
			local key = tonumber(mainAction) 
			itemedit.Components[key][subAction] = Value
		elseif ActionString == "Move" then
			Value2 = tonumber(ValueString2) or ValueString2 
			itemedit.Move(Vector2(Value, Value2), false)
		else
			itemedit[ActionString] = Value
		end
	end)

	Networking.Send(Networking.Start("serversettingsstart"))
	
	Networking.Receive("flipxclientnetwork", function (flipx)
	local itemedit = Entity.FindEntityByID(flipx.ReadUInt16())
	if itemedit then
		itemedit.FlipX(false)
	end
	end)
	
	Networking.Receive("flipyclientnetwork", function (flipy)
	local itemedit = Entity.FindEntityByID(flipy.ReadUInt16())
	if itemedit then
		itemedit.FlipY(false)
	end
	end)
	
	Networking.Receive("lualinker.add", function (msg)
		local itemedit1 = Entity.FindEntityByID(msg.ReadUInt16())
		local itemedit2 = Entity.FindEntityByID(msg.ReadUInt16())
		LinkAdd(itemedit1, itemedit2)
		if links == true then
			Links()
		end
	end)

	Networking.Receive("lualinker.remove", function (msg)
		local itemedit1 = Entity.FindEntityByID(msg.ReadUInt16())
		local itemedit2 = Entity.FindEntityByID(msg.ReadUInt16())
		LinkRemove(itemedit1, itemedit2)
		if links == true then
			Links()
		end
	end)
end
-- Client Side End --
