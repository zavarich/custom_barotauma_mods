local findtarget = {}
-- findowner
findtarget.FindClientCharacter = function(character)
    if CLIENT then return nil end
    
    for key, value in pairs(Client.ClientList) do
        if value.Character == character then
            return value
        end
    end
end






findtarget.cursor_pos = Vector2(0, 0)
findtarget.cursor_updated = false

local function StringToTable(inputString)
    local result = {}
   
	if inputString == nil then
		return result
	end
	
    for value in inputString:gmatch("[^,]+") do
        table.insert(result, value)
    end
    
    return result
end

local function itemsorwalls(submarine)

	if EditGUI.ClientsideSettings.targetingsetting == "Walls" and EditGUI.Settings.allowtargetingstructures == true then
		targeting = "walls"
		return submarine.GetWalls(false)
	elseif EditGUI.ClientsideSettings.targetingsetting == "Hulls" and EditGUI.Settings.allowtargetingstructures == true then
		targeting = "hulls"
		return submarine.GetHulls(false)
	elseif EditGUI.ClientsideSettings.targetingsetting == "Gaps" and EditGUI.Settings.allowtargetingstructures == true then
		targeting = "gaps"
		return submarine.GetGaps(false)
	else
		targeting = "items"
		return submarine.GetItems(false)
	end
end

local function FindClosestItem(submarine, position)
    local closest = nil
    for key, value in pairs(submarine and itemsorwalls(submarine) or Item.ItemList) do
		if targeting == "items" then
			if EditGUI.Settings.allowtargetingnoninteractable == true then
				if EditGUI.ClientsideSettings.targetnoninteractable == "False" then
					targetnoninter = value.NonInteractable == false
				elseif EditGUI.ClientsideSettings.targetnoninteractable == "Target Both" then
					targetnoninter = value.NonInteractable == false or true
				elseif EditGUI.ClientsideSettings.targetnoninteractable == "Target Only Non Interactable" then
					targetnoninter = value.NonInteractable == true
				end
			else
				targetnoninter = value.NonInteractable == false
			end
		else
			targetnoninter = true
		end
		
		if EditGUI.Settings.allowtargetingitems == true then
			targetitems = EditGUI.ClientsideSettings.targetitems
		else
			targetitems = false
		end
        
        -- Check if the item has a parent inventory
		if targeting == "items" then
			hasParentInventory = value.ParentInventory ~= nil
		end

        -- Skip items with parent inventories
        if hasParentInventory == EditGUI.ClientsideSettings.targetparentinventory or targeting ~= "items" then
            local hasValidTag = true
			
			if EditGUI.ClientsideSettings.tagstotarget ~= nil and targeting == "items" then
				for _, tag in ipairs(StringToTable(EditGUI.ClientsideSettings.tagstotarget)) do
					if value.HasTag(tag) then
						hasValidTag = true
						break
					else
						hasValidTag = false
					end
				end
			end

            for _, tag in ipairs(StringToTable(EditGUI.Settings.tagstonottarget)) do
                if value.HasTag(tag) then
                    hasValidTag = false
                    break
                end
            end

            if hasValidTag and targetnoninter then
                -- check if placable or if it does not have holdable component
                local check_if_p_or_nh = false
				if targeting == "items" then
					local holdable = value.GetComponentString("Holdable")
				end
				if targetitems == false then
					if holdable == nil then
						check_if_p_or_nh = true
					else
						if holdable.attachable == true then
							check_if_p_or_nh = true
						end
					end
				else
					check_if_p_or_nh = true
				end
                if check_if_p_or_nh == true then
                    if Vector2.Distance(position, value.WorldPosition) < 100 then
                        if closest == nil then closest = value end
                        if Vector2.Distance(position, value.WorldPosition) <
                            Vector2.Distance(position, closest.WorldPosition) then
                            closest = value
                        end
                    end
                end
            end
        end
    end
    return closest
end

findtarget.findtarget = function(item)
	cursor_updated = false
    if Client then
        findtarget.cursor_pos = item.ParentInventory.Owner.CursorWorldPosition
		cursor_updated = true
    end
	
    -- fallback
    if not cursor_updated and Game.IsMultiplayer then
        findtarget.cursor_pos = item.WorldPosition
    end

    if item.ParentInventory == nil or item.ParentInventory.Owner == nil then return end

    local target = FindClosestItem(item.Submarine, findtarget.cursor_pos)
    return target
end

return findtarget
