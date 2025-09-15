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

local function FindClosestItem(submarine, position)
    local closest = nil
    for key, value in pairs(submarine and submarine.GetItems(false) or Item.ItemList) do
        if value.Linkable and not value.HasTag("notlualinkable") and not value.HasTag("crate") and not value.HasTag("ammobox") and not value.HasTag("door") and not value.HasTag("smgammo") and not value.HasTag("hmgammo") and value.NonInteractable == false then
            -- check if placable or if it does not have holdable component
            local check_if_p_or_nh = false
            local holdable = value.GetComponentString("Holdable")
            if holdable == nil then
                check_if_p_or_nh = true
            else
                if holdable.attachable == true then
                    check_if_p_or_nh = true
                end
            end
            if check_if_p_or_nh == true then
                if Vector2.Distance(position, value.WorldPosition) < 100 then
                    if closest == nil then closest = value end
                    if Vector2.Distance(position, value.WorldPosition) <
                        Vector2.Distance(position, closest.WorldPosition) then
                        -- this should prevent items that are inside inventories from being linkable
                        if value.ParentInventory == nil then
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
    if CLIENT and Game.IsMultiplayer then 
        -- for better accuracy
        local client_cursor_pos = (item.ParentInventory.Owner).CursorWorldPosition
        local msg = Networking.Start("lualinker.clientsidevalue")
        msg.WriteSingle(client_cursor_pos.X)
        msg.WriteSingle(client_cursor_pos.Y)
        Networking.Send(msg)
        return
    end

	-- SinglePlayer
	if not Game.IsMultiplayer then
		findtarget.cursor_pos = item.ParentInventory.Owner.CursorWorldPosition
	end
    -- fallback
    if not findtarget.cursor_updated and Game.IsMultiplayer then
        findtarget.cursor_pos = item.WorldPosition
    end

    if item.ParentInventory == nil or item.ParentInventory.Owner == nil then return end

    local target = FindClosestItem(item.Submarine, findtarget.cursor_pos)
    return target
end

Networking.Receive("lualinker.clientsidevalue", function(msg)
    local position = Vector2(msg.ReadSingle(), msg.ReadSingle())
    findtarget.cursor_pos = position
    findtarget.cursor_updated = true
end)

return findtarget
